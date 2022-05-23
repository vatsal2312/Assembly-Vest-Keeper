/**
 *Submitted for verification at Etherscan.io on 2022-02-03
 */

pragma solidity =0.7.6;

// SPDX-License-Identifier: Unlicensed

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);
}

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;
        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }
}

contract Ownable is Context {
    address private _owner;

    constructor() {
        address msgSender = _msgSender();
        _owner = msgSender;
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }
}

contract SHIBURAIVESTKEEPER is Context, Ownable {
    using SafeMath for uint256;

    IERC20 public shiburai;
    uint256 public withdrawAmount;
    uint256 public waitTime;
    uint256 public maxHoldings;
    bool public withdrawEnabled;
    uint256 public contractShiburaiBalance;

    mapping(address => uint256) private balances;
    mapping(address => uint256) private lastWithdraw;

    constructor() {
        IERC20 _shiburai = IERC20(0x275EB4F541b372EfF2244A444395685C32485368);
        shiburai = _shiburai;
        withdrawAmount = 100000000000;
        waitTime = 1 days;
        maxHoldings = 10000000000;
    }

    function setWithdrawParameters(
        uint256 _amount,
        uint256 _numOfDays,
        uint256 _threshold,
        bool _enabled
    ) external onlyOwner {
        assembly {
            sstore(withdrawAmount.slot, mul(_amount, exp(10, 9)))
            sstore(waitTime.slot, mul(_numOfDays, 86400))
            sstore(withdrawEnabled.slot, _enabled)
            sstore(maxHoldings.slot, mul(_threshold, exp(10, 9)))
        }
    }

    function remainingVestedBalance(address _address)
        external
        view
        returns (uint256 _amount)
    {
        assembly {
            mstore(0, _address)
            mstore(32, balances.slot)
            let hash := keccak256(0, 64)
            _amount := sload(hash)
        }
    }

    function lastWithdrawnAt(address _address)
        external
        view
        returns (uint256 _At)
    {
        assembly {
            mstore(0, _address)
            mstore(32, lastWithdraw.slot)
            let hash := keccak256(0, 64)
            _At := sload(hash)
        }
    }

    //deposit remaining vest and update balances
    function setInitialBalance(address[] memory _addresses, uint256 _amount)
        external
        onlyOwner
    {
        uint256 _amountFromDev = (_addresses.length).mul(_amount * 10**9);
        require(
            shiburai.transferFrom(msg.sender, address(this), _amountFromDev),
            "Transfer failed"
        );
        uint256 _length = _addresses.length;
        assembly {
            sstore(
                contractShiburaiBalance.slot,
                add(sload(contractShiburaiBalance.slot), _amountFromDev)
            )
            let i := 0
            for {

            } lt(i, _length) {

            } {
                mstore(0, mload(add(add(_addresses, 0x20), mul(i, 0x20))))
                mstore(32, balances.slot)
                let hash := keccak256(0, 64)
                sstore(hash, add(sload(hash), mul(_amount, exp(10, 9))))
                i := add(i, 1)
            }
        }
    }

    //transfer Shiburai balance to this contract and update balance here
    function deposit() external {
        uint256 _amount = shiburai.balanceOf(msg.sender);
        require(
            shiburai.transferFrom(msg.sender, address(this), _amount),
            "Transfer failed"
        );
        assembly {
            mstore(0, caller())
            mstore(32, balances.slot)
            let hash := keccak256(0, 64)
            sstore(hash, add(sload(hash), _amount))
            sstore(
                contractShiburaiBalance.slot,
                add(sload(contractShiburaiBalance.slot), _amount)
            )
        }
    }

    //allows withdraw of vest if enough time has past since last withdraw and address balance is below maxholdings
    function withdraw() external {
        uint256 _balance = shiburai.balanceOf(msg.sender);
        require(_balance <= maxHoldings, "Cannot accumulate");
        require(balances[msg.sender] >= withdrawAmount, "Insuffecient Balance");
        require(
            lastWithdraw[msg.sender].add(waitTime) <= block.timestamp,
            "Must wait more time"
        );
        assembly {
            mstore(0, caller())
            mstore(32, lastWithdraw.slot)
            let hash := keccak256(0, 64)
            sstore(hash, timestamp())
        }
        shiburai.transfer(address(msg.sender), withdrawAmount);
        assembly {
            mstore(0, caller())
            mstore(32, balances.slot)
            let hash := keccak256(0, 64)
            let wAmount := mload(withdrawAmount.slot)
            sstore(hash, sub(sload(hash), wAmount))
            sstore(
                contractShiburaiBalance.slot,
                sub(mload(contractShiburaiBalance.slot), wAmount)
            )
        }
    }

    //to withdraw any remaining tokens after vesting has finished
    function claimRemainingBalanceAtEndOfVesting() external onlyOwner {
        shiburai.transfer(msg.sender, shiburai.balanceOf(address(this)));
    }

    function sync() external {
        contractShiburaiBalance = shiburai.balanceOf(address(this));
    }
}
