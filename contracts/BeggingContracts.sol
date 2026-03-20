// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title BeggingContract
 * @dev 讨饭合约（完整版）：支持捐赠、记录、提款、排行榜、时间限制、捐赠事件
 */
contract BeggingContract {
    // ======== 核心变量 ========
    // 合约所有者地址（不可修改）
    address public immutable owner;
    // 记录每个捐赠者的总捐赠金额 (捐赠者地址 => 总金额)
    mapping(address => uint256) public donationRecords;

    // ======== 时间限制相关 ========
    // 捐赠开始时间（时间戳，单位：秒）
    uint256 public donateStartTime;
    // 捐赠结束时间（时间戳，单位：秒）
    uint256 public donateEndTime;

    // ======== 排行榜相关 ========
    // 存储前3名捐赠者的地址和金额（按金额降序）
    address[3] public topDonors;
    uint256[3] public topDonations;

    // ======== 事件 ========
    // 捐赠事件：记录捐赠地址、金额、时间
    event Donation(address indexed donor, uint256 amount, uint256 timestamp);
    // 时间设置事件：记录开始/结束时间（方便追踪）
    event DonateTimeSet(uint256 startTime, uint256 endTime);

    // ======== 修饰符 ========
    // 仅所有者可调用
    modifier onlyOwner() {
        require(msg.sender == owner, "BeggingContract: only owner can call");
        _;
    }

    // 仅在捐赠时间范围内可调用
    modifier onlyDuringDonateTime() {
        uint256 nowTime = block.timestamp;
        require(
            nowTime >= donateStartTime && nowTime <= donateEndTime,
            "BeggingContract: donate is not available now"
        );
        _;
    }

    // ======== 构造函数 ========
    /**
     * @dev 构造函数：初始化所有者，默认时间范围为「部署后立即开始，永久有效」
     * 可通过 setDonateTime 函数修改时间范围
     */
    constructor() {
        owner = msg.sender;
        donateStartTime = block.timestamp; // 部署时立即开始
        donateEndTime = type(uint256).max; // 初始结束时间为最大值（永久有效）
    }

    // ======== 核心功能 ========
    /**
     * @dev 捐赠函数：接收以太币，记录捐赠信息，更新排行榜（仅在时间范围内可调用）
     * @notice 调用时需附带以太币，msg.value 为捐赠金额（wei）
     */
    function donate() public payable onlyDuringDonateTime {
        // 验证捐赠金额大于0
        require(msg.value > 0, "BeggingContract: donation amount must > 0");
        address donor = msg.sender;
        uint256 newAmount = donationRecords[donor] + msg.value;
        // 更新该捐赠者的总金额
        donationRecords[donor] = newAmount;

        // 更新捐赠排行榜
        updateTopDonors(donor, newAmount);

        // 触发捐赠事件
        emit Donation(donor, msg.value, block.timestamp);
    }

    /**
     * @dev 提取资金函数：仅所有者可提取合约中所有以太币
     */
    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "BeggingContract: no funds to withdraw");

        // 安全转账（替代 transfer，避免 2300 gas 限制问题）
        (bool success, ) = owner.call{value: balance}("");
        require(success, "BeggingContract: withdrawal failed");
    }

    /**
     * @dev 查询指定地址的捐赠金额
     * @param donor 捐赠者地址
     * @return 该地址的总捐赠金额（wei）
     */
    function getDonation(address donor) public view returns (uint256) {
        return donationRecords[donor];
    }

    // ======== 时间限制功能 ========
    /**
     * @dev 设置捐赠时间范围（仅所有者可调用）
     * @param _startTime 开始时间戳（秒）
     * @param _endTime 结束时间戳（秒）
     * @notice 需确保结束时间 > 开始时间
     */
    function setDonateTime(
        uint256 _startTime,
        uint256 _endTime
    ) public onlyOwner {
        require(
            _endTime > _startTime,
            "BeggingContract: end time must > start time"
        );
        donateStartTime = _startTime;
        donateEndTime = _endTime;
        emit DonateTimeSet(_startTime, _endTime);
    }

    // ======== 排行榜功能 ========
    /**
     * @dev 内部函数：更新前3名捐赠排行榜
     * @param donor 捐赠者地址
     * @param newAmount 该捐赠者的最新总捐赠金额
     */
    function updateTopDonors(address donor, uint256 newAmount) internal {
        // 遍历前3名，判断是否能进入排行榜
        for (uint256 i = 0; i < 3; i++) {
            if (newAmount > topDonations[i]) {
                // 腾出位置：将后面的元素后移一位
                if (i == 0 && topDonations[1] > 0) {
                    topDonations[2] = topDonations[1];
                    topDonors[2] = topDonors[1];
                    topDonations[1] = topDonations[0];
                    topDonors[1] = topDonors[0];
                } else if (i == 1 && topDonations[2] > 0) {
                    topDonations[2] = topDonations[1];
                    topDonors[2] = topDonors[1];
                }
                // 插入当前捐赠者到第i位
                topDonations[i] = newAmount;
                topDonors[i] = donor;
                break; // 插入后退出循环，避免重复插入
            }
        }
    }

    /**
     * @dev 获取完整的捐赠排行榜（前3名）
     * @return 地址数组（top1, top2, top3）、金额数组（top1金额, top2金额, top3金额）
     */
    function getTop3Donors()
        public
        view
        returns (address[3] memory, uint256[3] memory)
    {
        return (topDonors, topDonations);
    }

    // ======== 辅助函数 ========
    // 接收以太币的回退函数：直接调用 donate 函数（支持直接转币到合约地址）
    receive() external payable onlyDuringDonateTime {
        donate();
    }

    // 回退函数：防止意外调用（仅在时间范围内生效）
    fallback() external payable onlyDuringDonateTime {
        donate();
    }
}
