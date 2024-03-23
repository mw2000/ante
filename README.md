# Ante Smart Contract

The Ante smart contract is a versatile platform designed for staking on arbitrary claims or commitments, identified by a unique hash. It allows users to stake for or against these claims using either native Ether (automatically wrapped as WETH) or specified ERC20 tokens. This contract introduces dynamic odds to incentivize early participation and ensure balance between the opposing sides, making the staking process both fair and engaging.

NOTE: Please run tests with 
```
forge test --via-ir
```

## Features

### Dynamic Odds
The contract employs a dynamic odds system based on two main principles:
- **Early Staking Incentive**: Participants who stake early in the staking period are rewarded with more favorable odds.
- **Imbalance Adjustment**: The odds are adjusted to make staking on the less popular side more attractive, preventing imbalances.

### Time-Restricted Staking and Withdrawing
Each Ante comes with specific time constraints for both staking and withdrawing stakes:
- **Staking Period**: Users are allowed to stake within this predefined period, with incentives for early staking.
- **Unstaking Period**: Following the claim settlement, participants can withdraw their stakes and winnings only during this period.

### Support for ERC20 Tokens and Native ETH
Stakes can be made using ERC20 tokens or native Ether. Ether stakes are automatically wrapped into WETH for consistency in handling stakes across different token types.

### Claim Settlement
Only the author of an Ante has the authority to settle the claim, determining the winning side. Settlement triggers the payout process based on the accumulated stakes and the dynamic odds calculated at the time of each stake.

## Implementation

### Creating an Ante
To create an Ante, the author specifies a unique hash, the token address for staking, and the deadlines for staking and unstaking. The contract records the start of the staking period to apply early staking bonuses.

```solidity
function createAnte(string memory hash, address token, uint256 stakingDeadline, uint256 unstakingDeadline) external;
```

### Staking on an Ante
Users can stake on the Ante in favor or against the claim before the staking deadline. The odds are dynamically calculated at the time of staking, considering the timing and the stake imbalance.

```solidity
function stake(string memory hash, uint256 amount, bool isFor, address token) external payable;
```

### Unstaking and Claiming Winnings
After the Ante is settled, participants can unstake and claim their winnings within the unstaking period. This ensures fairness and adherence to the predefined staking rules.


```solidity
function unstake(string memory hash) external;
```

### Settling the Ante
The Ante's author finalizes the outcome, allowing the participants to unstake and receive their winnings based on the settled outcome and the dynamic odds.

```solidity
function settleAnte(string memory hash, bool outcome) external;
```

## Designing a Full-Stack System for Ante Smart Contracts

Creating a full-stack system for Ante smart contracts with the primary goal of offering the smoothest user experience (UX) requires careful selection of development tools and frameworks. The focus should be on simplifying interactions, improving transaction handling, and enhancing usability.

### Frontend Development: React and Wagmi

Utilizing **React** alongside **Wagmi**, a collection of React Hooks tailored for Ethereum, forms the foundation of our frontend development. This combination ensures a seamless integration with Ethereum wallets and smart contracts, crucial for intuitive user interactions.

#### Integration Highlights

- **Ethereum Wallet Connections**: Wagmi facilitates effortless wallet connections, streamlining the user's initial interaction with the DApp.
- **Transaction Feedback**: Provides users with immediate transaction status updates, enhancing transparency and trust.
- **Network Changes Management**: Automates the handling of network switches, maintaining a consistent UX across different Ethereum environments.

### Backend and Smart Contract Interaction

For backend processes and smart contract interactions, **Ethers.js** is preferred for its compatibility with Wagmi and ease of use in executing blockchain transactions and managing application state based on contract events.

#### Interaction Highlights

- **Simplified Contract Calls**: Abstract complex blockchain transactions into straightforward application functions, obscuring the backend complexities from the end-user.
- **Real-Time State Updates**: Utilize Ethers.js to monitor smart contract events, ensuring the DApp reflects the latest blockchain state.

### Account Abstraction and Smart Wallets

Integrating **account abstraction** through **smart wallets** can significantly elevate the UX by abstracting the complexities of transaction signing and gas fees, making the platform accessible even to blockchain novices.

#### Smart Wallet Implementation

- **Gas Fee Abstraction**: Incorporate relayer networks or similar services to handle gas fees, allowing users to perform transactions without needing ETH in their wallets.
- **Seamless Onboarding**: Leverage smart wallets for an effortless onboarding experience, enabling immediate platform interaction without traditional wallet setup hurdles.

### UX Simplification Strategies

Achieving the smoothest UX involves focusing on key areas for simplification:

- **Wallet Connection**: Implement a straightforward, guided process for wallet integration, minimizing barriers to entry.
- **Staking Workflow**: Streamline the staking journey with clear guidance and immediate feedback on transaction statuses.
- **User-Friendly Errors**: Translate technical blockchain errors into understandable messages, providing clear next steps for resolution.
- **Responsive Design**: Guarantee a responsive application, ensuring a uniform experience across various devices.

### Tools and Technologies Overview

- **Frontend**: Developed with React, integrated with Wagmi for Ethereum functionalities.
- **Backend/Blockchain**: Utilizes Ethers.js for smart contract interactions, with contracts deployed on Ethereum.
- **UX Enhancements**: Features account abstraction via smart wallets for streamlined experiences, alongside intuitive UI components and effective real-time state management.

## Bonus 1: People can withdraw their funds and stake again within the given period. What would this look like?

To incorporate the functionality where people can withdraw their funds and stake again within the given period into the Ante smart contract, several modifications are necessary. These changes aim to enhance flexibility for users, allowing them to adjust their stakes based on new information or strategies without waiting for the staking period to end. Here's a breakdown of the necessary changes:

### Modify the stake Function
The stake function needs to allow for additional staking within the staking period. This involves checking if the user already has a stake and, if so, adding to their current stake amount. The dynamic odds calculation should also be adjusted to account for the updated stake.

```solidity
function stake(string memory hash, uint256 amount, bool isFor, address token) external payable {
   // Existing validation logic...

   Stake storage userStake = stakes[hash][msg.sender];
   if (userStake.amount > 0) {
      // User is adding to their stake
      userStake.amount += amount;
   } else {
      // New stake
      userStake.amount = amount;
      userStake.isFor = isFor;
      userStake.odds = calculateOdds(hash, amount, isFor);
      userStake.timestamp = block.timestamp;
   }

   // Adjust total staked amounts
   if (isFor) {
      antes[hash].forTotal += amount;
   } else {
      antes[hash].againstTotal += amount;
   }

   emit Staked(msg.sender, hash, isFor, amount, userStake.odds);
}
```

### Implement a withdrawStake Function
To allow users to withdraw their stakes before the staking period ends, implement a withdrawStake function. This function should subtract from the user's current stake and the total staked amount on the chosen side. Care should be taken to prevent withdrawing more than the user's current stake.

```solidity
function withdrawStake(string memory hash, uint256 amount) external {
   require(block.timestamp <= antes[hash].stakingDeadline, "Cannot withdraw after staking period");
   
   Stake storage userStake = stakes[hash][msg.sender];
   require(userStake.amount >= amount, "Cannot withdraw more than the current stake");

   userStake.amount -= amount;
   if (userStake.isFor) {
      antes[hash].forTotal -= amount;
   } else {
      antes[hash].againstTotal -= amount;
   }

   // Return the withdrawn stake to the user
   IERC20(antes[hash].token).transfer(msg.sender, amount);

   emit StakeWithdrawn(msg.sender, hash, amount);
}
```

### Adjust the calculateOdds Function
The calculateOdds function should be adjusted to ensure it accurately reflects the current staking landscape, especially after stake withdrawals. This might involve recalculating odds based on the updated forTotal and againstTotal amounts whenever a stake is added or withdrawn.

## Bonus 2: Let’s say we allow users to put NFTs at stake. How would you achieve that? What are the challenges?

Incorporating NFT staking into a system like the Ante smart contract introduces several unique challenges, mainly due to the intrinsic properties of NFTs compared to fungible tokens. 
- Subjectivity and Variability: Unlike fungible tokens, NFTs have subjective values that can fluctuate widely based on demand, rarity, the artist's reputation, and community trends. Establishing a fair and dynamic valuation system for staking purposes is complex.
- Liquidity Concerns: The liquidity of NFTs can be significantly lower than that of fungible tokens, making it harder to realize their value instantly or use them as collateral.

## Conclusion
The Ante smart contract revolutionizes the concept of staking on claims by incorporating dynamic odds, early staking incentives, and mechanisms to maintain stake balance. By supporting a wide range of tokens, it offers flexibility and accessibility to participants, making it a comprehensive tool for decentralized betting and decision-making processes based on stakeholder consensus.




