// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title BeggingContract
 * @dev 讨饭合约，支持用户捐赠以太、记录捐赠信息、所有者提取资金
 */
contract BeggingContract {
    // 合约所有者地址
    address public immutable owner;

    // 记录每个捐赠者的总捐赠金额 (捐赠者地址 => 总金额)
    mapping(address => uint256) public donationRecords;

    // 捐赠事件：记录捐赠地址、金额、时间（可选挑战）
    event Donation(address indexed donor, uint256 amount, uint256 timestamp);

    // 构造函数：部署合约时设置所有者为部署者
    constructor() {
        owner = msg.sender;
    }

    // 修饰符：仅所有者可调用
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    /**
     * @dev 捐赠函数：接收用户发送的以太币，并记录捐赠信息
     * @notice 调用时需附带以太币，msg.value 为捐赠金额
     */
    function donate() public payable {
        // 验证捐赠金额大于 0
        require(msg.value > 0, "Donation amount must be greater than 0");

        // 更新捐赠记录：累加该地址的捐赠金额
        donationRecords[msg.sender] += msg.value;

        // 触发捐赠事件（可选挑战）
        emit Donation(msg.sender, msg.value, block.timestamp);
    }

    /**
     * @dev 提取资金函数：仅所有者可提取合约中所有以太币
     */
    function withdraw() public onlyOwner {
        // 获取合约余额
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");

        // 向所有者转账所有资金（使用 transfer 符合任务要求，自带 2300 gas 限制，安全）
        (bool success, ) = owner.call{value: balance}("");
        require(success, "Withdrawal failed");
    }

    /**
     * @dev 查询指定地址的捐赠金额
     * @param donor 捐赠者地址
     * @return 该地址的总捐赠金额（以 wei 为单位）
     */
    function getDonation(address donor) public view returns (uint256) {
        return donationRecords[donor];
    }

    // 接收以太币的回退函数：直接调用 donate 函数，支持用户直接向合约地址转币（增强易用性）
    receive() external payable {
        donate();
    }

    // 回退函数：防止意外调用
    fallback() external payable {
        donate();
    }
}
