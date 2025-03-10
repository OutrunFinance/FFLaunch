// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import {Initializable} from "../libraries/Initializable.sol";
import {IFFLiquidProof} from "./interfaces/IFFLiquidProof.sol";

/**
 * @title FFLaunch Liquid Of Proof(POL) Token
 */
contract FFLiquidProof is IFFLiquidProof, Initializable {
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;
    address public launcher;

    mapping(address account => uint256) public balances;
    mapping(address account => mapping(address spender => uint256)) public allowances;

    modifier onlyFFLauncher() {
        require(msg.sender == launcher, PermissionDenied());
        _;
    }

    /**
     * @notice Initialize the liquid proof.
     * @param _name - The name of the liquid proof.
     * @param _symbol - The symbol of the liquid proof.
     * @param _decimals - The decimals of the liquid proof.
     * @param _launcher - The address of the FFLauncher.
     */
    function initialize(
        string memory _name, 
        string memory _symbol, 
        uint8 _decimals, 
        address _launcher
    ) external override initializer {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        launcher = _launcher;
    }

    function balanceOf(address account) external view override returns (uint256) {
        return balances[account];
    }

    function allowance(address owner, address spender) external view override returns (uint256) {
        return allowances[owner][spender];
    }

    function mint(address account, uint256 amount) external override onlyFFLauncher {
        _mint(account, amount);
    }

    function burn(address account, uint256 value) external onlyFFLauncher returns (bool) {
        require(balances[account] >= value, InsufficientBalance());
        _burn(account, value);
        return true;
    }

    function transfer(address to, uint256 value) public override returns (bool) {
        address owner = msg.sender;
        _transfer(owner, to, value);
        return true;
    }

    function approve(address spender, uint256 value) public override returns (bool) {
        address owner = msg.sender;
        _approve(owner, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        address spender = msg.sender;
        _spendAllowance(from, spender, value);
        _transfer(from, to, value);
        return true;
    }

    function _transfer(address from, address to, uint256 value) internal {
        require(from != address(0), ERC20InvalidSender(address(0)));
        require(to != address(0), ERC20InvalidReceiver(address(0)));
        
        _update(from, to, value);
    }

    function _update(address from, address to, uint256 value) internal {
        if (from == address(0)) {
            totalSupply += value;
        } else {
            uint256 fromBalance = balances[from];
            require(fromBalance >= value, ERC20InsufficientBalance(from, fromBalance, value));
            unchecked {
                balances[from] = fromBalance - value;
            }
        }

        if (to == address(0)) {
            unchecked {
                totalSupply -= value;
            }
        } else {
            unchecked {
                balances[to] += value;
            }
        }

        emit Transfer(from, to, value);
    }

    function _mint(address account, uint256 value) internal {
        require(account != address(0), ERC20InvalidReceiver(address(0)));
        _update(address(0), account, value);
    }

    function _burn(address account, uint256 value) internal {
        require(account != address(0), ERC20InvalidSender(address(0)));
        _update(account, address(0), value);
    }

    function _approve(address owner, address spender, uint256 value) internal {
        _approve(owner, spender, value, true);
    }

    function _approve(address owner, address spender, uint256 value, bool emitEvent) internal {
        require(owner != address(0), ERC20InvalidApprover(address(0)));
        require(spender != address(0), ERC20InvalidSpender(address(0)));

        allowances[owner][spender] = value;
        if (emitEvent) {
            emit Approval(owner, spender, value);
        }
    }

    function _spendAllowance(address owner, address spender, uint256 value) internal {
        uint256 currentAllowance = allowances[owner][spender];
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= value, ERC20InsufficientAllowance(spender, currentAllowance, value));
            unchecked {
                _approve(owner, spender, currentAllowance - value, false);
            }
        }
    }
}
