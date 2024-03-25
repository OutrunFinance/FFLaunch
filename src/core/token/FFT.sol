// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import "./interfaces/IFFT.sol";
import "../../blast/GasManagerable.sol";

/**
 * @title FF Token Standard
 */
abstract contract FFT is IFFT, GasManagerable {
    string private _name;
    string private _symbol;
    uint8 private _decimals;
    uint256 private _totalSupply;
    address private _launcher;
    address private _callee;
    bool private _isTransferable; // Enable after FFLaunch is completed.

    mapping(address account => uint256) private _balances;
    mapping(address account => mapping(address spender => uint256)) private _allowances;

    modifier onlyCallee() {
        require(msg.sender == _callee, "Only launchPool callee");
        _;
    }

    constructor(
        string memory name_, 
        string memory symbol_, 
        address launcher_, 
        address callee_, 
        address _gasManager
    ) GasManagerable(_gasManager) {
        _name = name_;
        _symbol = symbol_;
        _launcher = launcher_;
        _callee = callee_;
    }

    function _msgSender() internal view returns (address) {
        return msg.sender;
    }

    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function launcher() public view override returns (address) {
        return _launcher;
    }

    function callee() public view override returns (address) {
        return _callee;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transferable() external view override returns (bool) {
        return _isTransferable;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function enableTransfer() external override {
        require(!_isTransferable, "Already enable transfer");
        require(msg.sender == _launcher, "Permission denied");
        _isTransferable = true;
    }

    function mint(address _account, uint256 _amount) external override onlyCallee {
        _mint(_account, _amount);
    }

    function burn(address _account, uint256 _amount) external override onlyCallee {
        _burn(_account, _amount);
    }

    function transfer(address to, uint256 value) public override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, value);
        return true;
    }

    function approve(address spender, uint256 value) public override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, value);
        _transfer(from, to, value);
        return true;
    }

    function _transfer(address from, address to, uint256 value) internal {
        if (from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }

        if (_isTransferable) {
            _update(from, to, value);
        } else {
            revert TransferNotStart();
        }
    }

    function _update(address from, address to, uint256 value) internal {
        if (from == address(0)) {
            _totalSupply += value;
        } else {
            uint256 fromBalance = _balances[from];
            if (fromBalance < value) {
                revert ERC20InsufficientBalance(from, fromBalance, value);
            }
            unchecked {
                _balances[from] = fromBalance - value;
            }
        }

        if (to == address(0)) {
            unchecked {
                _totalSupply -= value;
            }
        } else {
            unchecked {
                _balances[to] += value;
            }
        }

        emit Transfer(from, to, value);
    }

    function _mint(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(address(0), account, value);
    }

    function burn(uint256 value) external returns (bool) {
        address burner = _msgSender();
        require(balanceOf(burner) >= value, "Insufficient balance");
        _burn(burner, value);
        return true;
    }

    function _burn(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        _update(account, address(0), value);
    }

    function _approve(address owner, address spender, uint256 value) internal {
        _approve(owner, spender, value, true);
    }

    function _approve(address owner, address spender, uint256 value, bool emitEvent) internal {
        if (owner == address(0)) {
            revert ERC20InvalidApprover(address(0));
        }
        if (spender == address(0)) {
            revert ERC20InvalidSpender(address(0));
        }
        _allowances[owner][spender] = value;
        if (emitEvent) {
            emit Approval(owner, spender, value);
        }
    }

    function _spendAllowance(address owner, address spender, uint256 value) internal {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < value) {
                revert ERC20InsufficientAllowance(spender, currentAllowance, value);
            }
            unchecked {
                _approve(owner, spender, currentAllowance - value, false);
            }
        }
    }
}
