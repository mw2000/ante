// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {PRBTest} from "@prb/test/src/PRBTest.sol";
import {Ante} from "../src/Ante.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {MockWETH} from "../src/mocks/MockWETH.sol";

contract AnteTest is PRBTest {
    Ante public anteContract;
    MockWETH public weth;

    address public owner;
    address public alice;
    address public bob;
    address public charlie;
    address public dana;
    address public eve;

    function setUp() public {
        owner = address(this);
        alice = address(0x1);
        bob = address(0x2);
        charlie = address(0x3);
        dana = address(0x4);
        eve = address(0x5);

        weth = new MockWETH();
        anteContract = new Ante(address(weth));

        weth.mint(alice, 1 ether);
        weth.mint(bob, 1 ether);
        weth.mint(charlie, 1 ether);
        weth.mint(dana, 1 ether);
        weth.mint(eve, 1 ether);

        vm.startPrank(alice);
        weth.approve(address(anteContract), 1 ether);
        vm.stopPrank();

        vm.startPrank(bob);
        weth.approve(address(anteContract), 1 ether);
        vm.stopPrank();

        vm.startPrank(charlie);
        weth.approve(address(anteContract), 1 ether);
        vm.stopPrank();

        vm.startPrank(dana);
        weth.approve(address(anteContract), 1 ether);
        vm.stopPrank();

        vm.startPrank(eve);
        weth.approve(address(anteContract), 1 ether);
        vm.stopPrank();
    }

    // This test checks if the Ante can be created successfully
    function testCreateAnte() public {
        string memory hash = "hash1";
        uint256 stakingDeadline = block.timestamp + 1 days;
        uint256 unstakingDeadline = stakingDeadline + 1 days;

        vm.prank(owner);
        anteContract.createAnte(hash, address(weth), stakingDeadline, unstakingDeadline);
        (address author,, address token,,, bool settled,,, uint256 _stakingDeadline, uint256 _unstakingDeadline) = 
            anteContract.antes(hash);

        // Ante.AnteInfo memory anteInfo = anteContract.);
        assertEq(author, owner);
        assertEq(token, address(weth));
        assertEq(_stakingDeadline, stakingDeadline);
        assertEq(_unstakingDeadline, unstakingDeadline);
        assertFalse(settled);
    }

    // This tests if users can stake and unstake
    function testStakeAndUnstake() public {
        string memory hash = "hash1";
        uint256 stakingStartTime = block.timestamp;
        uint256 stakingDeadline = block.timestamp + 1 days;
        uint256 unstakingDeadline = stakingDeadline + 6 days;

        vm.prank(owner);
        anteContract.createAnte(hash, address(weth), stakingDeadline, unstakingDeadline);

        // Stake within the staking deadline
        vm.warp(block.timestamp + 12 hours); // Move time forward within staking period
        vm.prank(alice);
        anteContract.stake(hash, 0.5 ether, true, address(weth));
        vm.prank(bob);
        anteContract.stake(hash, 0.5 ether, false, address(weth));

        // Attempt to stake after staking deadline (should fail)
        vm.warp(stakingDeadline + 1); // Move time just past staking deadline
        vm.expectRevert("Staking period has ended");
        vm.prank(charlie);
        anteContract.stake(hash, 0.1 ether, true, address(weth));

        // Settle the Ante (after staking deadline, before unstaking deadline)
        vm.prank(owner);
        anteContract.settleAnte(hash, true); // Assume "for" wins

        // Move time to within unstaking period and then unstake successfully
        vm.warp(stakingDeadline + 2 days); // Within the unstaking period
        vm.prank(alice);
        anteContract.unstake(hash);

        // Attempt to unstake after unstaking deadline (should fail)
        vm.warp(unstakingDeadline + 1); // Move time beyond unstaking deadline
        vm.expectRevert("Unstaking period has ended");
        vm.prank(bob);
        anteContract.unstake(hash);
    }

    // This test checks if the dynamic odds and payouts 
    // work correctly when there are 2 stakers
    function testTwoStakersDynamicOddsAndPayouts() public {
        string memory hash = "hashDynamicOdds";
        uint256 stakingStartTime = block.timestamp;
        uint256 stakingDeadline = block.timestamp + 1 days;
        uint256 unstakingDeadline = stakingDeadline + 6 days;

        anteContract.createAnte(hash, address(weth), stakingDeadline, unstakingDeadline);

        // Simulate an early stake by Alice
        vm.prank(alice);
        anteContract.stake(hash, 0.5 ether, true, address(weth));
        (,,uint256 aliceOdds,) = anteContract.stakes(hash, alice);

        // Simulate a slightly later stake by Bob to test dynamic odds adjustments
        vm.warp(block.timestamp + 6 hours); // Move time forward within the staking window
        vm.prank(bob);
        anteContract.stake(hash, 0.5 ether, false, address(weth));

        uint256 balanceAliceBefore = weth.balanceOf(alice);
        uint256 balanceBobBefore = weth.balanceOf(bob);

        vm.warp(stakingDeadline + 1); // Move time to just after the staking deadline
        vm.prank(owner);
        anteContract.settleAnte(hash, true); // Settle the Ante, assuming "for" wins

        // Ensure unstaking happens within the allowed window
        vm.warp(unstakingDeadline - 3 days); // Move time to within the unstaking window

        vm.prank(alice);
        anteContract.unstake(hash);
        vm.prank(bob);
        anteContract.unstake(hash);

        uint256 balanceAliceAfter = weth.balanceOf(alice);
        uint256 balanceBobAfter = weth.balanceOf(bob);

        // Calculate expected payout for Alice, factoring in her dynamic odds
        uint256 expectedPayoutAlice = 0.5 ether + ((0.5 ether * aliceOdds) / 100);

        // Assert Alice's balance increased by the expected payout amount minus her initial stake
        assertEq(balanceAliceAfter, balanceAliceBefore + expectedPayoutAlice - 0.5 ether, "Incorrect payout for Alice");

        // Assert Bob's balance remains unchanged since "against" lost and losers forfeit their stake
        assertEq(balanceBobAfter, balanceBobBefore, "Bob's balance should not change.");
    }


    // This test checks if the dynamic odds and payouts 
    // work correctly when there are five stakers
    function testFiveStakersDynamicOddsAndPayouts() public {
        string memory hash = "hashDynamicOdds";
        uint256 stakingStartTime = block.timestamp;
        uint256 stakingDeadline = block.timestamp + 1 days;
        uint256 unstakingDeadline = stakingDeadline + 7 days;

        anteContract.createAnte(hash, address(weth), stakingDeadline, unstakingDeadline);

        // Early stakers (Alice and Charlie)
        vm.prank(alice);
        anteContract.stake(hash, 0.5 ether, true, address(weth));
        (,,uint256 oddsAlice,) = anteContract.stakes(hash, alice);

        vm.warp(block.timestamp + 1 hours); // Slightly later staker (Charlie)
        vm.prank(charlie);
        anteContract.stake(hash, 0.3 ether, true, address(weth));
        (,,uint256 oddsCharlie,) = anteContract.stakes(hash, charlie);

        // Mid-period stakers (Dana and Bob)
        vm.warp(block.timestamp + 6 hours);
        vm.prank(dana);
        anteContract.stake(hash, 0.2 ether, true, address(weth));
        (,,uint256 oddsDana,) = anteContract.stakes(hash, dana);

        vm.prank(bob);
        anteContract.stake(hash, 0.5 ether, false, address(weth));

        // Late staker (Eve)
        vm.warp(block.timestamp + 12 hours);
        vm.prank(eve);
        anteContract.stake(hash, 0.4 ether, false, address(weth));

        vm.warp(stakingDeadline + 1); // Fast forward time to after the staking deadline
        vm.prank(owner);
        anteContract.settleAnte(hash, true); // Assume "for" wins

        uint256 aliceBalanceBefore = weth.balanceOf(alice);
        uint256 charlieBalanceBefore = weth.balanceOf(charlie);
        uint256 danaBalanceBefore = weth.balanceOf(dana);

        vm.warp(unstakingDeadline - 2 days); // Unstake within the unstaking period
        // Unstaking for each participant
        vm.prank(alice);
        anteContract.unstake(hash);
        vm.prank(charlie);
        anteContract.unstake(hash);
        vm.prank(dana);
        anteContract.unstake(hash);
        vm.prank(eve);
        anteContract.unstake(hash);

        // Balance checks after unstaking
        uint256 aliceExpectedPayout = calculateExpectedPayout(0.5 ether, oddsAlice, true); 
        uint256 charlieExpectedPayout = calculateExpectedPayout(0.3 ether, oddsCharlie, true);
        uint256 danaExpectedPayout = calculateExpectedPayout(0.2 ether, oddsDana, true);
        
        // Now assert the actual balance matches the expected balance (initial balance + expected payout)
        assertEq(weth.balanceOf(alice), aliceBalanceBefore + aliceExpectedPayout - 0.5 ether, 
            "Incorrect payout for Alice");
        assertEq(weth.balanceOf(charlie), charlieBalanceBefore + charlieExpectedPayout -  0.3 ether, 
            "Incorrect payout for Charlie");
        assertEq(weth.balanceOf(dana), danaBalanceBefore + danaExpectedPayout - 0.2 ether, 
            "Incorrect payout for Dana");

        vm.warp(unstakingDeadline + 1); // Attempt to unstake past deadline
        vm.expectRevert("Unstaking period has ended");
        vm.prank(bob);
        anteContract.unstake(hash);
    }

    // Example function to calculate expected payout
    // Note: This is conceptual and needs to be adjusted based on actual payout logic
    function calculateExpectedPayout(uint256 stakeAmount, uint256 odds, bool isWinner) private pure returns (uint256) {
        if (!isWinner) return 0; // Losers do not receive a payout
        return stakeAmount + (stakeAmount * odds / 100);
    }
}