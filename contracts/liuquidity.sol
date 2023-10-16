// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

import "./lptoken.sol";

contract AMM{

    struct LpData{
        address tokenA;
        address tokenB;
        address lpAddr;
        uint reserveA;
        uint reserveB;
        uint createdTime;
        uint A;
        uint lpFee;
    }

    mapping(uint => LpData) public _lpInfo;
    mapping(address => mapping(address => uint)) public _findIndex;
    uint _index;
    address [] private _stableLpTokenAddressList;


    function addLiquidityWithStablePair(address _token0, address _token1, uint _amount0,uint _amount1, uint _A,uint _lpFee) public returns (uint shares) {
        
        
        //一些简单的需求
        require(_amount0 > 0 ,"require _amount0 > 0 && _amount1 >0");
        require(_token0 != _token1, "_token0 == _token1");
        require(_findIndex[_token0][_token1] == 0,"alredy add liquidity");

        //用户转移token到AMM
        IERC20 token0 = IERC20(_token0);
        IERC20 token1 = IERC20(_token1);
        token0.transferFrom(msg.sender, address(this), _amount0);
        token1.transferFrom(msg.sender, address(this), _amount1);

        _index++;
        _findIndex[_token0][_token1] = _index;
        _findIndex[_token1][_token0] = _index;
        //创造lptoken和返回lpAddr
        address lpAddr = createStablePair(_token0,_token1);

        //用户得到的shares的算法
        shares = _sqrt(_amount0 * _amount1);

        //token为用户添加流动性的凭证  
        require(shares > 0, "shares = 0");
        //mint lptoken 给user
        lptoken lptoken1 = lptoken(lpAddr);
        lptoken1.mint(msg.sender,shares);

        
        //把lp的数据写入
        _lpInfo[_index] = LpData(_token0,_token1,lpAddr,_amount0,_amount1,block.timestamp,_A, _lpFee);
    }

    function addLiquidityWithStablePairByUser(address _token0, address _token1, uint _amount0) public returns (uint shares) {
        
        
        require(_amount0 > 0 ,"require _amount0 > 0 && _amount1 >0");
        require(_findIndex[_token0][_token1] != 0,"invalid tokenpair");
        //找到index
        uint index = _findIndex[_token1][_token0];
        //获取token储备
        uint reserve0 = _lpInfo[index].reserveA;
        uint reserve1 = _lpInfo[index].reserveB;
        //根据添加token0的数量计算添加多少
        uint amount1 =   reserve1 * _amount0 / reserve0;
        IERC20 token0 = IERC20(_token0);
        IERC20 token1 = IERC20(_token1);
        token0.transferFrom(msg.sender, address(this), _amount0);
        token1.transferFrom(msg.sender, address(this), amount1);
        //创建lptoken
        address lpAddr = _lpInfo[index].lpAddr;
        //计算user可以得到的share
        lptoken lptoken1 = lptoken(lpAddr);
        shares = _min(
            (_amount0 * lptoken1.totalSupply()) / reserve0,
            (amount1 * lptoken1.totalSupply()) / reserve1
        );
            //获取lptoken地址
        require(shares > 0, "shares = 0");
        lptoken1.mint(msg.sender,shares);

        

        //更新数据
        _lpInfo[index].reserveA += _amount0;
        _lpInfo[index].reserveB += amount1;

    }

    function removeLiquidityWithStableCoin(
        address _token0,
        address _token1,
        uint _shares
    ) public  returns (uint amount0, uint amount1) {
        //找到index
        uint index = _findIndex[_token1][_token0];
        address lpAddr = _lpInfo[index].lpAddr;


        //if(pairCreator[lptokenAddr] == msg.sender)
        //{
        //    require(lptoken.balanceOf(msg.sender) - _shares > 100 ,"paieCreator should left 100 wei lptoken in pool");
        //}
        //计算出lptoken能赎回多少token
        lptoken lptoken1 = lptoken(lpAddr);
        amount0 = (_shares * _lpInfo[index].reserveA) / lptoken1.totalSupply();
        amount1 = (_shares * _lpInfo[index].reserveB) / lptoken1.totalSupply();
        require(amount0 > 0 && amount1 > 0, "amount0 or amount1 = 0");


        lptoken1.burn(msg.sender, _shares);
        //更新储备量
        _lpInfo[index].reserveA -= amount0;
        _lpInfo[index].reserveB -= amount1;

        //发送token给用户
        IERC20 token0 = IERC20(_token0);
        IERC20 token1 = IERC20(_token1);
        token0.transfer(msg.sender, amount0);
        token1.transfer(msg.sender, amount1);
    }

    function swapWithStableCoin(address _tokenIn, address _tokenOut, uint _amountIn)  public returns(uint amountOut){
        uint index = _findIndex[_tokenIn][_tokenOut];
        require(
            index != 0,
            "invalid token"
        );
        
        require(_amountIn > 0, "amount in = 0");
        require(_tokenIn != _tokenOut);

        uint reserveIn;
        uint reserveOut;  
        //address lptokenAddr = _lpInfo[index].lpAddr;

        _tokenIn == _lpInfo[index].tokenA?(reserveIn,reserveOut) = (_lpInfo[index].reserveA,_lpInfo[index].reserveB):(reserveIn,reserveOut) = (_lpInfo[index].reserveB,_lpInfo[index].reserveA);


        //require(isStablePair[findLpToken[_tokenIn][_tokenOut]],"not stablePair");

        IERC20 tokenIn = IERC20(_tokenIn);
        IERC20 tokenOut = IERC20(_tokenOut);

        
        //暂停交易（to do）
        //require(!getLpSwapStatic(lptokenAddr),"swapPair pausing");

        tokenIn.transferFrom(msg.sender, address(this), _amountIn);


        //交易税收 
        uint amountInWithFee = (_amountIn * (100000-_lpInfo[index].lpFee)) / 100000;
        //amountOut = (reserveOut * amountInWithFee) / (reserveIn + amountInWithFee);
        amountOut = calOutput(_lpInfo[index].A,reserveIn + reserveOut, reserveIn,amountInWithFee);

        //检查滑点
        //setSli(amountInWithFee,reserveIn,reserveOut,_disirSli);
        //setSliBystable(amountOut,amountInWithFee,reserveIn,reserveOut,_disirSli);


        tokenOut.transfer(msg.sender, amountOut);
        //uint totalReserve0 = reserve[lptokenAddr][_tokenIn] + _amountIn; 
        //uint totalReserve1 = reserve[lptokenAddr][_tokenOut] - amountOut;

        //uint profit = userFee * _amountIn / 10000;

       // _lpProfit[lptokenAddr] += profit;
        if(_tokenIn == _lpInfo[index].tokenA)
       {
            _lpInfo[index].reserveA += _amountIn;
            _lpInfo[index].reserveB -= amountOut;
       }else 
       {
            _lpInfo[index].reserveB += _amountIn;
            _lpInfo[index].reserveA -= amountOut;           
       }


    }



    function _sqrt(uint y) private pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function _min(uint x, uint y) private pure returns (uint) {
        return x <= y ? x : y;
    }

    function createStablePair(address addrToken0, address addrToken1) internal returns(address){
        bytes32 _salt = keccak256(
            abi.encodePacked(
                addrToken0,addrToken1,"stablecoin"
            )
        );
        address lptokenAddr = address(new lptoken{
            salt : bytes32(_salt)
        }
        ());

        _stableLpTokenAddressList.push(lptokenAddr);


        return lptokenAddr;
    }

    function getBytecode() internal pure returns(bytes memory) {
        bytes memory bytecode = type(lptoken).creationCode;
        return bytecode;
    }

    function getAddress(bytes memory bytecode, bytes32 _salt)
        internal
        view
        returns(address)
    {
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff), address(this), _salt, keccak256(bytecode)
            )
        );

        return address(uint160(uint(hash)));
    }



    function calOutAmount(uint A, uint D, uint X)public pure returns(uint)
    {
        //return  (4*A*D*D*X+calSqrt(A, D, X) -4*X-4*A*D*X*X) / (8*A*D*X);
        uint a = 4*A*D*X+D*calSqrt(A, D, X)-4*A*X*X-D*X;
        //uint amountOut2 = y - amountOut1;
        return a/(8*A*X);

    }

    function calOutput(uint A, uint D, uint X,uint dx)public pure returns(uint)
    {
        //D = D * 10**18;
        //X = X * 10**18;
        //dx = dx* 10**18;
        uint S = X + dx;
        uint amount1 = calOutAmount(A, D, X);
        uint amount2 = calOutAmount(A, D, S);

        //uint amountOut2 = y - amountOut1;
        return amount1 - amount2;

    }

    


    function calSqrt(uint A, uint D, uint X)public pure returns(uint)
    {
        //uint T = t(A,D,X);
        //uint calSqrtNum = _sqrt((X*(4+T))*(X*(4+T))+T*T*D*D+4*T*D*D-2*X*T*D*(4+T));
        //return calSqrtNum;
        (uint a, uint b) = (4*A*X*X/D+X,4*A*X);
        uint c;
        if(a>=b){
            c = a -b;
        }else{
            c = b-a;
        }

        return _sqrt(c*c+4*D*X*A);

    }
}
