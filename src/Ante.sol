// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Interface for WETH
interface IWETH {
    function deposit() external payable;
    function withdraw(uint256) external;
    function transfer(address to, uint256 value) external returns (bool);
}

// Main contract
contract Ante {
    // Struct for individual stakes
    struct Stake {
        uint256 amount; // The amount staked
        bool isFor; // Whether the stake is for or against the Ante
        uint256 odds; // The odds for the stake
        uint256 timestamp; // The timestamp when the stake was made
    }

    // Struct for Ante information
    struct AnteInfo {
        address author; // The address of the author of the Ante
        string hash; // The hash representing the Ante
        address token; // The token address for the Ante
        uint256 forTotal; // The total amount staked for the Ante
        uint256 againstTotal; // The total amount staked against the Ante
        bool settled; // Whether the Ante has been settled
        bool outcome; // The outcome of the Ante
        uint256 stakingStartTime; // The start time for staking
        uint256 stakingDeadline; // The deadline for staking
        uint256 unstakingDeadline; // The deadline for unstaking
    }

    IWETH public weth; // The WETH contract
    mapping(string => AnteInfo) public antes; // Mapping from Ante hash to AnteInfo
    mapping(string => mapping(address => Stake)) public stakes; // Mapping from Ante hash and staker address to Stake

    // Event emitted when a stake is made
    event Staked(address indexed user, string hash, bool isFor, uint256 amount, uint256 odds);
    // Event emitted when a stake is withdrawn
    event Unstaked(address indexed user, string hash, uint256 amount);

    // Constructor for the contract
    constructor(address _weth) {
        weth = IWETH(_weth);
    }

    /**
    * @dev Creates a new Ante
    * @param hash The hash representing the Ante
    * @param token The token address for the Ante
    * @param stakingDeadline The deadline for staking on the Ante
    * @param unstakingDeadline The deadline for unstaking from the Ante
    */
    function createAnte(string memory hash, address token, uint256 stakingDeadline, uint256 unstakingDeadline) external {
        require(antes[hash].author == address(0), "Ante already exists");
        require(token != address(0), "Invalid token address");
        require(stakingDeadline > block.timestamp, "Invalid staking deadline");
        require(unstakingDeadline > stakingDeadline, "Invalid unstaking deadline");
        
        AnteInfo storage ante = antes[hash];
        ante.author = msg.sender;
        ante.hash = hash;
        ante.token = token;
        ante.stakingStartTime = block.timestamp;
        ante.stakingDeadline = stakingDeadline;
        ante.unstakingDeadline = unstakingDeadline;
    }

    /**
    * @dev Allows a user to stake on an Ante
    * @param hash The hash representing the Ante
    * @param amount The amount to stake
    * @param isFor Whether the stake is for or against the Ante
    * @param token The token address for the stake
    */
    function stake(string memory hash, uint256 amount, bool isFor, address token) external payable {
        require(token != address(0) && token == antes[hash].token, "Invalid token for this Ante");
        require(block.timestamp >= antes[hash].stakingStartTime, "Staking period has not started");
        require(block.timestamp <= antes[hash].stakingDeadline, "Staking period has ended");

        if(token == address(weth) && msg.value > 0) {
            require(amount == msg.value, "Amount does not match value sent");
            weth.deposit{value: msg.value}();
        } else {
            require(msg.value == 0, "Cannot send ETH with ERC20 stake");
            require(IERC20(token).transferFrom(msg.sender, address(this), amount), "Transfer failed");
        }

        AnteInfo storage ante = antes[hash];
        require(ante.author != address(0), "Ante does not exist");

        uint256 odds = calculateOdds(hash, amount, isFor);

        Stake storage _stake = stakes[hash][msg.sender];
        _stake.amount += amount;
        _stake.isFor = isFor;
        _stake.odds = odds;
        _stake.timestamp = block.timestamp;

        if(isFor) {
            ante.forTotal += amount;
        } else {
            ante.againstTotal += amount;
        }

        emit Staked(msg.sender, hash, isFor, amount, odds);
    }

    /**
    * @dev Calculates dynamic odds for a stake
    * @param hash The hash representing the Ante
    * @param amount The amount of the stake
    * @param isFor Whether the stake is for or against the Ante
    * @return The calculated odds
    */
    function calculateOdds(string memory hash, uint256 amount, bool isFor) internal view returns (uint256) {
        AnteInfo storage ante = antes[hash];
        uint256 forTotal = ante.forTotal;
        uint256 againstTotal = ante.againstTotal;

        uint256 timeBasedMultiplier = calculateTimeBasedMultiplier(ante.stakingStartTime, ante.stakingDeadline);
        uint256 imbalanceAdjustment;
        if (forTotal + againstTotal > 0) {
            uint256 ratio = isFor ? (forTotal + amount) * 100 / (forTotal + againstTotal + amount) :
                                    (againstTotal + amount) * 100 / (forTotal + againstTotal + amount);
            imbalanceAdjustment = 100 + (100 - ratio);
        } else {
            imbalanceAdjustment = 100;
        }

        uint256 odds = timeBasedMultiplier * imbalanceAdjustment / 100;

        return odds;
    }

    /**
    * @dev Calculates time-based multiplier for a stake
    * @param startTime The start time for staking
    * @param deadline The deadline for staking
    * @return The calculated time-based multiplier
    */
    function calculateTimeBasedMultiplier(uint256 startTime, uint256 deadline) internal view returns (uint256) {
        uint256 elapsedTime = block.timestamp - startTime;
        uint256 totalTime = deadline - startTime;
        if (elapsedTime > totalTime) {
            return 100; // No bonus if beyond deadline
        }
        // Example: Linear decrease in multiplier from 150% at start to 100% at deadline
        return 150 - (50 * elapsedTime / totalTime);
    }

    /**
    * @dev Allows a user to unstake from an Ante
    * @param hash The hash representing the Ante
    */
    function unstake(string memory hash) external {
        require(antes[hash].settled, "Ante not settled");
        Stake storage userStake = stakes[hash][msg.sender];
        require(userStake.amount > 0, "No stake to withdraw");
        require(block.timestamp >= antes[hash].stakingDeadline, "Unstaking period is yet to start");
        require(block.timestamp <= antes[hash].unstakingDeadline, "Unstaking period has ended");


        AnteInfo storage ante = antes[hash];
        bool userWon = (userStake.isFor && ante.outcome) || (!userStake.isFor && !ante.outcome);

        uint256 stakeAmount = userStake.amount;
        uint256 payout = 0;

        if (userWon) {
            uint256 multiplier = userStake.odds;
            payout = stakeAmount * multiplier / 100;
        }

        userStake.amount = 0;

        if (userWon) {
            IERC20 anteToken = IERC20(ante.token);
            require(anteToken.transfer(msg.sender, payout), "Failed to transfer winnings");
        }

        emit Unstaked(msg.sender, hash, payout);
    }

    /**
    * @dev Allows the Ante author to settle the Ante
    * @param hash The hash representing the Ante
    * @param outcome The outcome of the Ante
    */
    function settleAnte(string memory hash, bool outcome) external {
        require(msg.sender == antes[hash].author, "Only author can settle");
        AnteInfo storage ante = antes[hash];
        require(!ante.settled, "Ante already settled");

        ante.settled = true;
        ante.outcome = outcome;
    }
}