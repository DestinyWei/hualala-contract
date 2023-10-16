// SPDX-License-Identifier: MIT

import "./IAMM.sol";
import "./Idatastore.sol";
import "./StableAlgorithm.sol";
import "./lptoken.sol";



pragma solidity ^0.8.9;


contract longlogic{
    IAMM amm;
    uint constant ONE_ETH = 10 ** 18;
    constructor(address _amm){
        amm = IAMM(_amm);

    }

    function resetAmm(address _amm) public {
        amm = IAMM(_amm);
    }


    function getTokenPrice(address _tokenA, address _tokenB) public view returns(uint reserveA,uint reserveB, uint one_tokenA_price,uint one_tokenB_price)
    {
        address lptokenAddr = amm.getLptoken(_tokenA,_tokenB);
        reserveA = amm.getReserve(lptokenAddr, _tokenA);
        reserveB = amm.getReserve(lptokenAddr,_tokenB);

        one_tokenA_price = reserveB * ONE_ETH / reserveA;
        one_tokenB_price = reserveA * ONE_ETH / reserveB;

            
    }

    function getTokenPriceStableCoin(address _tokenA, address _tokenB, uint amountIn) public view returns(uint reserveA,uint reserveB, uint tokenA_price,uint tokenB_price)
    {
        address lptokenAddr = amm.getStableLptoken(_tokenA,_tokenB);
        reserveA = amm.getReserve(lptokenAddr, _tokenA);
        reserveB = amm.getReserve(lptokenAddr,_tokenB);
        tokenA_price = calOutput(amm.getA(lptokenAddr),reserveA + reserveB, reserveA,amountIn);
        tokenB_price = calOutput(amm.getA(lptokenAddr),reserveA + reserveB, reserveB,amountIn);

        
        //tokenOutAmount = StableAlgorithm.calOutput(100,reserveA + reserveB, reserveA,_tokenInAmount);



            
    }

    function cacalTokenOutAmountWithStableCoin(address _tokenIn, address _tokenOut, uint _amountIn) public view returns(uint reserveIn,uint reserveOut,uint amountOut, uint priceImpact){
        require(_amountIn > 0, "amount in = 0");
        require(_tokenIn != _tokenOut);

        address lptokenAddr = amm.getStableLptoken(_tokenIn,_tokenOut);
        reserveIn = amm.getReserve(lptokenAddr,_tokenIn);
        reserveOut = amm.getReserve(lptokenAddr,_tokenOut);



        //交易税收 
        uint amountInWithFee = (_amountIn * (100000-amm.getStableLpFee()-amm.getFundFee())) / 100000;
        //amountOut = (reserveOut * amountInWithFee) / (reserveIn + amountInWithFee);
        amountOut = calOutput(amm.getA(lptokenAddr),reserveIn + reserveOut, reserveIn,amountInWithFee);

        reserveIn += _amountIn;
        reserveOut -= amountOut;

        uint amountOut2 = calOutput(amm.getA(lptokenAddr),reserveIn + reserveOut, reserveIn,amountInWithFee);

        priceImpact = (amountOut - amountOut2)*ONE_ETH/amountOut;





    }

    function cacalTokenOutAmount(address _tokenIn, address _tokenOut, uint _tokenInAmount) public view returns(uint tokenOutAmount)
    {
        address lptokenAddr = amm.getLptoken(_tokenIn,_tokenOut);
        uint reserveIn = amm.getReserve(lptokenAddr, _tokenIn);
        uint reserveOut = amm.getReserve(lptokenAddr,_tokenOut);

        tokenOutAmount = (reserveOut * _tokenInAmount) / (reserveIn + _tokenInAmount);
    }

    function cacalLpTokenAddAmount(address _tokenA, address _tokenB, uint _amountA) public view returns(uint _amountB)
    {
        address lptokenAddr = amm.getLptoken(_tokenA,_tokenB);
        _amountB = amm.getReserve(lptokenAddr,_tokenB) * _amountA / amm.getReserve(lptokenAddr, _tokenA);
    }


 

    function getRemoveLiquidityAmount(
        address _token0,
        address _token1,
        uint _shares
    ) public view  returns (uint amount0, uint amount1) {
        //ILPToken lptoken;//lptoken接口，为了mint 和 burn lptoken
        address lptokenAddr = amm.getLptoken(_token0,_token1);

        //lptoken = ILPToken(lptokenAddr);


        amount0 = (_shares * amm.getReserve(lptokenAddr,_token0)) / lptoken(lptokenAddr).totalSupply();//share * totalsuply/bal0
        amount1 = (_shares * amm.getReserve(lptokenAddr,_token1)) / lptoken(lptokenAddr).totalSupply();
    }

    function getRemoveLiquidityAmountStableLp(
        address _token0,
        address _token1,
        uint _shares
    ) public view  returns (uint amount0, uint amount1) {
        //ILPToken lptoken;//lptoken接口，为了mint 和 burn lptoken
        address lptokenAddr = amm.getStableLptoken(_token0,_token1);

        //lptoken = ILPToken(lptokenAddr);


        amount0 = (_shares * amm.getReserve(lptokenAddr,_token0)) / lptoken(lptokenAddr).totalSupply();//share * totalsuply/bal0
        amount1 = (_shares * amm.getReserve(lptokenAddr,_token1)) / lptoken(lptokenAddr).totalSupply();
    }

    function lptokenTotalSupplyForUser(address _token0, address _token1, address user) public view returns(uint)
    {
        //ILPToken lptoken;
        //lptoken = ILPToken(amm.getLptoken(_token0,_token1));
        uint userTotalSupply = lptoken(amm.getLptoken(_token0,_token1)).balanceOf(user);
        return userTotalSupply;
    }

    function stableLptokenTotalSupplyForUser(address _token0, address _token1, address user) public view returns(uint)
    {
        //ILPToken lptoken;
        //lptoken = ILPToken(amm.getStableLptoken(_token0,_token1));
        uint userTotalSupply = lptoken(amm.getStableLptoken(_token0,_token1)).balanceOf(user);
        return userTotalSupply;
    }

    function lptokenTotalSupply(address _token0, address _token1) public view returns(uint)
    {
        //ILPToken lptoken;
        //lptoken = ILPToken(amm.getLptoken(_token0,_token1));
        uint TotalSupply = lptoken(amm.getLptoken(_token0,_token1)).totalSupply();
        return TotalSupply;
    }

    function stableLptokenTotalSupply(address _token0, address _token1) public view returns(uint)
    {
        //ILPToken lptoken;
        //lptoken = ILPToken(amm.getStableLptoken(_token0,_token1));
        uint TotalSupply = lptoken(amm.getStableLptoken(_token0,_token1)).totalSupply();
        return TotalSupply;
    }

    function calAddStableLiquidityAmount(address _token0, address _token1, uint _amount0) public view returns (uint amount1) {
        address lptokenAddr = amm.getStableLptoken(_token1,_token0);
        //require(isStablePair[lptokenAddr],"not StablePair");
        amount1 =   amm.getReserve(lptokenAddr,_token1) * _amount0 / amm.getReserve(lptokenAddr,_token0);

    }

    function calAddLiquidityAmount(address _token0, address _token1, uint _amount0) public view returns (uint amount1) {
        address lptokenAddr = amm.getLptoken(_token1,_token0);
        //require(isStablePair[lptokenAddr],"not StablePair");
        amount1 =   amm.getReserve(lptokenAddr,_token1) * _amount0 / amm.getReserve(lptokenAddr,_token0);

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




    function _sqrt(uint y) public pure returns (uint z) {
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



    

    
}
