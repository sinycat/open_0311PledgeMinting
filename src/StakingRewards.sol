// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
// import "./EsRNT.sol";


interface IEsRNT {
    function mint(address to, uint256 amount) external;
}

// 质押挖矿合约
contract StakingRewards is Ownable {
    using SafeERC20 for IERC20;

    IERC20 public rnt; // RNT 代币
    IERC20 public esRnt; // esRNT 奖励代币

    uint256 public constant REWARD_RATE = 1e18; // 每质押 1 RNT 每天奖励 1 esRNT (精度 1e18)
    uint256 public constant LOCK_PERIOD = 30 days; // esRNT 锁仓周期
    uint256 public constant REWARD_DURATION = 30 days; // 质押奖励周期

    // 用户质押信息
    struct UserStake {
        uint256 amount; // 质押的 RNT 数量
        uint256 startTime; // 质押开始时间
        uint256 rewardDebt; // 已领取的奖励
    }

    // 用户锁仓信息 (esRNT 兑换 RNT)
    struct LockInfo {
        uint256 amount; // 锁仓的 esRNT 数量
        uint256 lockStartTime; // 锁仓开始时间
    }

    mapping(address => UserStake) public userStakes; // 用户质押信息
    mapping(address => LockInfo[]) public userLocks; // 用户锁仓信息

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 amount);
    event Redeemed(address indexed user, uint256 esRntAmount, uint256 rntAmount, uint256 burnedAmount);

    constructor(address _rnt, address _esRnt) Ownable(msg.sender) {
        rnt = IERC20(_rnt);
        esRnt = IERC20(_esRnt);
    }

    // 计算用户当前可领取的 esRNT 奖励
    function pendingRewards(address user) public view returns (uint256) {
        UserStake memory userStake = userStakes[user]; // 重命名变量，避免冲突
        if (userStake.amount == 0) return 0;

        uint256 stakingTime = block.timestamp - userStake.startTime;
        if (stakingTime > REWARD_DURATION) {
            stakingTime = REWARD_DURATION; // 质押超过 30 天不再产生奖励
        }

        // 每秒奖励 = (质押数量 * 奖励率) / 1 天秒数
        uint256 totalReward = (userStake.amount * stakingTime * REWARD_RATE) / (1 days * 1e18);
        return totalReward - userStake.rewardDebt;
    }

    // 质押 RNT
    function stake(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");

        UserStake storage userStake = userStakes[msg.sender]; // 重命名变量，避免冲突
        if (userStake.amount > 0) {
            // 如果已有质押，先领取奖励
            _claimReward();
        } else {
            userStake.startTime = block.timestamp;
        }

        userStake.amount = userStake.amount + amount;
        rnt.safeTransferFrom(msg.sender, address(this), amount);

        emit Staked(msg.sender, amount);
    }

    // 解押 RNT
    function unstake(uint256 amount) external {
        UserStake storage userStake = userStakes[msg.sender]; // 重命名变量，避免冲突
        require(userStake.amount >= amount, "Insufficient staked amount");
        require(amount > 0, "Amount must be greater than 0");

        // 先领取奖励
        _claimReward();

        userStake.amount = userStake.amount - amount;
        if (userStake.amount == 0) {
            userStake.startTime = 0; // 重置开始时间
        } else {
            userStake.startTime = block.timestamp; // 重置奖励计算时间
        }

        rnt.safeTransfer(msg.sender, amount);

        emit Unstaked(msg.sender, amount);
    }

    // 领取 esRNT 奖励
    function claimReward() external {
        _claimReward();
    }

    // 内部函数：领取奖励并更新状态
    function _claimReward() internal {
        uint256 reward = pendingRewards(msg.sender);
        if (reward > 0) {
            UserStake storage userStake = userStakes[msg.sender];
            userStake.rewardDebt = userStake.rewardDebt + reward;

            // 奖励的 esRNT 进入锁仓状态
            userLocks[msg.sender].push(LockInfo({
                amount: reward,
                lockStartTime: block.timestamp
            }));

            // 直接铸造 esRNT 奖励
            IEsRNT(address(esRnt)).mint(msg.sender, reward);

            emit RewardClaimed(msg.sender, reward);
        }
    }

    // 兑换 esRNT 为 RNT
    function redeem(uint256 lockIndex) external {
        LockInfo storage lock = userLocks[msg.sender][lockIndex];
        require(lock.amount > 0, "Invalid lock index");

        uint256 esRntAmount = lock.amount;
        uint256 lockTime = block.timestamp - lock.lockStartTime;

        // 计算可释放的 RNT 数量
        uint256 rntAmount;
        uint256 burnedAmount;
        if (lockTime >= LOCK_PERIOD) {
            // 锁仓期满，全部释放
            rntAmount = esRntAmount;
            burnedAmount = 0;
        } else {
            // 提前兑换，按比例释放
            rntAmount = (esRntAmount * lockTime) / LOCK_PERIOD;
            burnedAmount = esRntAmount - rntAmount;
        }

        // 清空锁仓记录
        lock.amount = 0;

        // 转移并销毁所有的 esRNT
        esRnt.safeTransferFrom(msg.sender, address(this), esRntAmount);
        ERC20Burnable(address(esRnt)).burn(esRntAmount);

        // 释放 RNT
        if (rntAmount > 0) {
            rnt.safeTransfer(msg.sender, rntAmount);
        }

        emit Redeemed(msg.sender, esRntAmount, rntAmount, burnedAmount);
    }

    // 获取用户锁仓记录数量
    function getLockCount(address user) external view returns (uint256) {
        return userLocks[user].length;
    }

    // 提取合约中的 RNT (仅限管理员)
    function emergencyWithdraw(uint256 amount) external onlyOwner {
        rnt.safeTransfer(msg.sender, amount);
    }
}