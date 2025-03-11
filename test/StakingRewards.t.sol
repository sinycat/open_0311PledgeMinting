// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/StakingRewards.sol";
import "../src/RNT.sol";
import "../src/EsRNT.sol";

contract StakingRewardsTest is Test {
    RNT rnt;
    EsRNT esRnt;
    StakingRewards stakingRewards;

    address owner = address(this);
    address user1 = address(0x1);
    address user2 = address(0x2);

    uint256 constant INITIAL_RNT_SUPPLY = 1_000_000 ether; // 1,000,000 RNT
    uint256 constant STAKE_AMOUNT = 100 ether; // 100 RNT
    uint256 constant REWARD_RATE = 1 ether; // 1 esRNT per RNT per day
    uint256 constant LOCK_PERIOD = 30 days; // 30 days
    uint256 constant REWARD_DURATION = 30 days; // 30 days

    function setUp() public {
        // 部署 RNT 代币合约
        rnt = new RNT();

        // 部署 esRNT 代币合约
        esRnt = new EsRNT();

        // 部署 StakingRewards 合约
        stakingRewards = new StakingRewards(address(rnt), address(esRnt));

        // 将 esRnt 的 owner 设置为 StakingRewards 合约
        esRnt.transferOwnership(address(stakingRewards));

        // 给用户分配 RNT 代币
        rnt.transfer(user1, 1000 ether); // 给 user1 1000 RNT
        rnt.transfer(user2, 1000 ether); // 给 user2 1000 RNT

        // 给 StakingRewards 合约分配 RNT 用于奖励兑换
        rnt.transfer(address(stakingRewards), 10_000 ether); // 10,000 RNT
    }

    function testStake() public {
        // user1 授权 StakingRewards 合约转移 RNT
        vm.startPrank(user1);
        rnt.approve(address(stakingRewards), STAKE_AMOUNT);

        // user1 质押 100 RNT
        vm.expectEmit(true, true, false, true);
        emit StakingRewards.Staked(user1, STAKE_AMOUNT);
        stakingRewards.stake(STAKE_AMOUNT);
        vm.stopPrank();

        // 验证质押信息
        (uint256 amount, uint256 startTime, ) = stakingRewards.userStakes(user1);
        assertEq(amount, STAKE_AMOUNT);
        assertGt(startTime, 0);

        // 验证 RNT 余额
        assertEq(rnt.balanceOf(user1), 900 ether); // 1000 - 100
        assertEq(rnt.balanceOf(address(stakingRewards)), 10_100 ether); // 10,000 + 100
    }

    function testStakeAdditional() public {
        // user1 质押 100 RNT
        vm.startPrank(user1);
        rnt.approve(address(stakingRewards), STAKE_AMOUNT * 2);
        stakingRewards.stake(STAKE_AMOUNT);

        // 快进 1 天
        vm.warp(block.timestamp + 1 days);

        // 质押更多 RNT
        stakingRewards.stake(STAKE_AMOUNT);
        vm.stopPrank();

        // 验证质押信息
        (uint256 amount, , ) = stakingRewards.userStakes(user1);
        assertEq(amount, STAKE_AMOUNT * 2);
    }

    function testUnstake() public {
        // user1 质押 100 RNT
        vm.startPrank(user1);
        rnt.approve(address(stakingRewards), STAKE_AMOUNT);
        stakingRewards.stake(STAKE_AMOUNT);

        // user1 解押 50 RNT
        vm.expectEmit(true, true, false, true);
        emit StakingRewards.Unstaked(user1, STAKE_AMOUNT / 2);
        stakingRewards.unstake(STAKE_AMOUNT / 2);
        vm.stopPrank();

        // 验证质押信息
        (uint256 amount, , ) = stakingRewards.userStakes(user1);
        assertEq(amount, STAKE_AMOUNT / 2);

        // 验证 RNT 余额
        assertEq(rnt.balanceOf(user1), 950 ether); // 900 + 50
        assertEq(rnt.balanceOf(address(stakingRewards)), 10_050 ether); // 10,100 - 50
    }

    function testUnstakeAll() public {
        // user1 质押 100 RNT
        vm.startPrank(user1);
        rnt.approve(address(stakingRewards), STAKE_AMOUNT);
        stakingRewards.stake(STAKE_AMOUNT);

        // user1 解押全部
        stakingRewards.unstake(STAKE_AMOUNT);
        vm.stopPrank();

        // 验证质押信息
        (uint256 amount, uint256 startTime, ) = stakingRewards.userStakes(user1);
        assertEq(amount, 0);
        assertEq(startTime, 0);
    }

    function testPendingRewards() public {
        // user1 质押 100 RNT
        vm.startPrank(user1);
        rnt.approve(address(stakingRewards), STAKE_AMOUNT);
        stakingRewards.stake(STAKE_AMOUNT);
        vm.stopPrank();

        // 快进 1 天
        vm.warp(block.timestamp + 1 days);

        // 验证奖励 (100 RNT * 1 esRNT/RNT/day = 100 esRNT)
        uint256 pending = stakingRewards.pendingRewards(user1);
        assertEq(pending, STAKE_AMOUNT);

        // 快进到 30 天
        vm.warp(block.timestamp + REWARD_DURATION - 1 days);

        // 验证奖励 (100 RNT * 30 days = 3000 esRNT)
        uint256 pendingAfter30Days = stakingRewards.pendingRewards(user1);
        assertEq(pendingAfter30Days, STAKE_AMOUNT * 30);

        // 快进到 31 天，奖励不再增加
        vm.warp(block.timestamp + 1 days);
        uint256 pendingAfter31Days = stakingRewards.pendingRewards(user1);
        assertEq(pendingAfter31Days, STAKE_AMOUNT * 30);
    }

    function testClaimReward() public {
        // user1 质押 100 RNT
        vm.startPrank(user1);
        rnt.approve(address(stakingRewards), STAKE_AMOUNT);
        stakingRewards.stake(STAKE_AMOUNT);
        vm.stopPrank();

        // 快进 1 天
        vm.warp(block.timestamp + 1 days);

        // 领取奖励
        vm.startPrank(user1);
        vm.expectEmit(true, true, false, true);
        emit StakingRewards.RewardClaimed(user1, STAKE_AMOUNT);
        stakingRewards.claimReward();
        vm.stopPrank();

        // 验证锁仓记录
        uint256 lockCount = stakingRewards.getLockCount(user1);
        assertEq(lockCount, 1);

        // 验证 esRNT 余额
        assertEq(esRnt.balanceOf(user1), STAKE_AMOUNT);
    }

    function testRedeemFull() public {
        // user1 质押 100 RNT
        vm.startPrank(user1);
        rnt.approve(address(stakingRewards), STAKE_AMOUNT);
        stakingRewards.stake(STAKE_AMOUNT);
        vm.stopPrank();

        // 快进 1 天并领取奖励
        vm.warp(block.timestamp + 1 days);
        vm.startPrank(user1);
        stakingRewards.claimReward();

        // 快进到锁仓期满 (30 天)
        vm.warp(block.timestamp + LOCK_PERIOD);

        // 授权 StakingRewards 燃烧 esRNT
        esRnt.approve(address(stakingRewards), STAKE_AMOUNT);

        // 兑换 esRNT 为 RNT
        vm.expectEmit(true, true, false, true);
        emit StakingRewards.Redeemed(user1, STAKE_AMOUNT, STAKE_AMOUNT, 0);
        stakingRewards.redeem(0);
        vm.stopPrank();

        // 验证 RNT 余额
        assertEq(rnt.balanceOf(user1), 1000 ether); // 900 + 100

        // 验证 esRNT 余额
        assertEq(esRnt.balanceOf(user1), 0);
    }

    function testRedeemPartial() public {
        // user1 质押 100 RNT
        vm.startPrank(user1);
        rnt.approve(address(stakingRewards), STAKE_AMOUNT);
        stakingRewards.stake(STAKE_AMOUNT);
        vm.stopPrank();

        // 快进 1 天并领取奖励
        vm.warp(block.timestamp + 1 days);
        vm.startPrank(user1);
        stakingRewards.claimReward();

        // 快进 15 天 (锁仓期的一半)
        vm.warp(block.timestamp + 15 days);

        // 授权 StakingRewards 燃烧 esRNT
        esRnt.approve(address(stakingRewards), STAKE_AMOUNT);

        // 兑换 esRNT 为 RNT (应释放 50%，燃烧 50%)
        uint256 expectedRnt = STAKE_AMOUNT / 2;
        uint256 expectedBurned = STAKE_AMOUNT / 2;
        vm.expectEmit(true, true, false, true);
        emit StakingRewards.Redeemed(user1, STAKE_AMOUNT, expectedRnt, expectedBurned);
        stakingRewards.redeem(0);
        vm.stopPrank();

        // 验证 RNT 余额
        assertEq(rnt.balanceOf(user1), 950 ether); // 900 + 50

        // 验证 esRNT 余额
        assertEq(esRnt.balanceOf(user1), 0);
    }

    function testEmergencyWithdraw() public {
        uint256 contractBalanceBefore = rnt.balanceOf(address(stakingRewards));
        stakingRewards.emergencyWithdraw(STAKE_AMOUNT);

        // 验证 RNT 余额
        assertEq(rnt.balanceOf(address(stakingRewards)), contractBalanceBefore - STAKE_AMOUNT);
        assertEq(rnt.balanceOf(owner), INITIAL_RNT_SUPPLY - 2000 ether - 10_000 ether + STAKE_AMOUNT);
    }

    function testEmergencyWithdrawNonOwner() public {
        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user1)
        );
        stakingRewards.emergencyWithdraw(STAKE_AMOUNT);
        vm.stopPrank();
    }

    function testGetLockCount() public {
        // user1 质押 100 RNT
        vm.startPrank(user1);
        rnt.approve(address(stakingRewards), STAKE_AMOUNT);
        stakingRewards.stake(STAKE_AMOUNT);
        vm.stopPrank();

        // 快进 1 天并领取奖励
        vm.warp(block.timestamp + 1 days);
        vm.startPrank(user1);
        stakingRewards.claimReward();
        vm.stopPrank();

        // 验证锁仓记录数量
        uint256 lockCount = stakingRewards.getLockCount(user1);
        assertEq(lockCount, 1);
    }
}