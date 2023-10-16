// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface ICToken{
    function underlying() external view returns(address);
    function mint(address minter, uint mintAmount) external returns (uint);
    function redeem(address payable redeemer, uint redeemTokens) external returns (uint);
    function redeemUnderlying(address payable redeemer,uint redeemAmount) external returns (uint);

    function borrow(uint borrowAmount) external returns (uint);
    function repayBorrow(uint repayAmount) external returns (uint);
    function repayBorrowBehalf(address borrower, uint repayAmount) external returns (uint);
    //function liquidateBorrow(address borrower, uint repayAmount, CTokenInterface cTokenCollateral) external returns (uint);
    //function sweepToken(EIP20NonStandardInterface token) external;

    function _reduceReserves(uint amount) external returns (uint);
}

interface IComptroller{
    function mintAllowed(address cToken, address minter, uint mintAmount) external view returns (bool);
    function borrowAllowed(address cToken, address borrower, uint borrowAmount) external view returns (bool);
    function repayBorrowAllowed(address cToken, address payer, address borrower, uint repayAmount) external view returns (bool);
    function redeemAllowed(address cToken, address redeemer, uint redeemTokens) external view returns (bool);
    function marketList(uint index) external view returns(address);
    function getMarketLength() external view returns(uint);
}

interface IRouter{
    function balanceOf(address token) external view returns(uint);                      //查询DEX中某一token的数目
    function transferTo(address borrower, address token, uint amount) external;                    //router中给CToken权限转走DEX中任意数目的币
    //function getPoolAddr(address tokenA) external view returns(address);                //router自动计算出来应该往哪个池子转币
    function updateBalance() external;                                                  //通知router，有币转进去了，要更新账本
}

abstract contract ERC20 {
    mapping(address account => uint256) private _balances;

    mapping(address account => mapping(address spender => uint256)) private _allowances;

    mapping(address => bool) public userPause;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view virtual returns (string memory) {
        return _name;
    }

    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual returns (uint8) {
        return 18;
    }

    function totalSupply() public view virtual returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 value) public virtual returns (bool) {
        address owner = msg.sender;
        _transfer(owner, to, value);
        return true;
    }

    function allowance(address owner, address spender) public view virtual returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 value) public virtual returns (bool) {
        address owner = msg.sender;
        _approve(owner, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) public virtual returns (bool) {
        address spender = msg.sender;
        _spendAllowance(from, spender, value);
        _transfer(from, to, value);
        return true;
    }

    function _transfer(address from, address to, uint256 value) internal {
        require(!userPause[from], "u must repay the borrow");
        if (from == address(0)) {
            revert();
        }
        if (to == address(0)) {
            revert();
        }
        _update(from, to, value);
    }

    function _update(address from, address to, uint256 value) internal virtual {
        if (from == address(0)) {
            // Overflow check required: The rest of the code assumes that totalSupply never overflows
            _totalSupply += value;
        } else {
            uint256 fromBalance = _balances[from];
            if (fromBalance < value) {
                revert();
            }
            unchecked {
                // Overflow not possible: value <= fromBalance <= totalSupply.
                _balances[from] = fromBalance - value;
            }
        }

        if (to == address(0)) {
            unchecked {
                // Overflow not possible: value <= totalSupply or value <= fromBalance <= totalSupply.
                _totalSupply -= value;
            }
        } else {
            unchecked {
                // Overflow not possible: balance + value is at most totalSupply, which we know fits into a uint256.
                _balances[to] += value;
            }
        }

        // emit Transfer(from, to, value);
    }

    function _mint(address account, uint256 value) internal {
        if (account == address(0)) {
            revert();
        }
        _update(address(0), account, value);
    }

    function _burn(address account, uint256 value) internal {
        if (account == address(0)) {
            revert();
        }
        _update(account, address(0), value);
    }

    function _approve(address owner, address spender, uint256 value) internal {
        _approve(owner, spender, value, true);
    }

    function _approve(address owner, address spender, uint256 value, bool emitEvent) internal virtual {
        if (owner == address(0)) {
            revert();
        }
        if (spender == address(0)) {
            revert();
        }
        _allowances[owner][spender] = value;
        if (emitEvent) {
            // emit Approval(owner, spender, value);
        }
    }

    function _spendAllowance(address owner, address spender, uint256 value) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < value) {
                revert();
            }
            unchecked {
                _approve(owner, spender, currentAllowance - value, false);
            }
        }
    }
}

contract MyToken is ERC20{
    address public CToken;
    address public router;
    address public owner;
    address public comptroller;
    constructor()
        ERC20("MyToken", "MTK")
    {
        owner = msg.sender;
    }

    function _setAddress(address CToken_, address router_, address comptroller_) external {
        require(msg.sender == owner);
        CToken = CToken_;
        router = router_;
        comptroller = comptroller_;
    }

    function addLiquidity(uint256 amount) public {
        _mint(msg.sender, amount);
        ICToken(CToken).mint(msg.sender,amount);
    }

    function removeLiquidity(uint256 amount) public {
        ICToken(CToken).redeem(payable(msg.sender), amount);        //确定一下拆LP的流程
        _burn(msg.sender, amount);
    }

    function removeLiquidityAndEarn(uint256 amount) public {
        ICToken(CToken).redeem(payable(msg.sender), amount);
        _burn(msg.sender, amount);
        uint len = IComptroller(comptroller).getMarketLength();
        for(uint i=0; i<len; i++){
            address cToken = IComptroller(comptroller).marketList(i);
            address underlying = ICToken(CToken).underlying();
            uint earnAmount = IERC20(underlying).balanceOf(cToken);
            if(earnAmount > 0){
                ICToken(CToken)._reduceReserves(earnAmount);
            }
        }
        IRouter(router).updateBalance();
    }

    function disableTransfer(address user, uint amount) external{
        // require(msg.sender == CToken, "only CToken");
        userPause[user] = true;
    }

    function enableTransfer(address user, uint amount) external{
        // require(msg.sender == CToken, "only CToken");
        userPause[user] = false;
    }

}
