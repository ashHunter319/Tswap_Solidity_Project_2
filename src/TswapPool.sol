// SPDX-License-Identifier: GNU General Public License v3.0
pragma solidity ^0.8.20;

import {SafeERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20, IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract TswapPool is ERC20{

    error TswapPool_mustBeMoreThanZero();
    error TswapPool_wethToDepositAmountToLow(uint256 MINIMUM_WETH_LIQUIDITY, uint256 wethToDeposit);
    error TswapPool_MaxPoolTokenDepositIsTooHigh(uint256 maximum, uint256 poolTokensToDeposite);
    error TswapPool_MinPoolTokenDepositIsTooLow(uint256 minimumLiquidityTokensToMint, uint256 liquidityTokensToMint);
    error TswapPool_OutPutTooLow(uint256 actual, uint256 min);
    error TswapPool_DeadlineHasPassed(uint64 deadline);
    error TswapPool_invalidToken();


    using SafeERC20 for IERC20;

    uint256 private constant MINIMUM_WETH_LIQUIDITY = 1_000_000_000;
    IERC20 private immutable i_wethToken;
    IERC20 private immutable i_poolToken;
    uint256 private constant MAX_SWAP_COUNT = 10;
    uint256 private swap_count = 0 ;


    event LiquidityAdded(address indexed LiquidityProvider, uint256 wetToDeposited, uint256 poolTokenDeposited );
    event LiquidityRemoved(address indexed LiquidityProvider, uint256 wethToWithdraw, uint256 poolTokensToWithdraw);
    event swap(address indexed swapper, IERC20 tokenIn, uint256 amountTokenIn, IERC20 tokenOut, uint256 ampuntTokenOut);


    modifier revertIfZero(uint256 amount)
    {
        if(amount == 0)
        revert TswapPool_mustBeMoreThanZero();
        _;
    }

    modifier revertIfDeadlinePassed(uint64 deadline){
        if(deadline < uint64(block.timestamp)){
            revert TswapPool_DeadlineHasPassed(deadline);

        }
        _;
    }

    constructor(
        address poolToken,
        address wethToken,
        string memory liquidityTokenName,
        string memory liquidityTokensymbol
    ) ERC20(liquidityTokenName, liquidityTokensymbol) {
        
        i_wethToken = IERC20(wethToken);
        i_poolToken = IERC20(poolToken);

    }

    function deposit (uint256 wethToDeposit, 
    uint256 minimumLiquidityTokensToMint, 
    uint256 maximumPoolTokensToDeposite, 
    uint256 deadline) 
    external revertIfZero(wethToDeposit) returns(uint256 liquidityTokensToMint){


        if(wethToDeposit < MINIMUM_WETH_LIQUIDITY){
            revert TswapPool_wethToDepositAmountToLow(
                MINIMUM_WETH_LIQUIDITY,
                wethToDeposit
            );
        }
       

       if(totalLiquidityTokenSupply()>0){
        uint256  wethReserve= i_wethToken.balanceOf(address(this));
        uint256 poolTokenReserve = i_poolToken.balanceOf(address(this));

        uint256 poolTokensToDeposite = getPoolTokenToDeposit(wethToDeposit);

        if(maximumPoolTokensToDeposite < poolTokensToDeposite){
            revert TswapPool_MaxPoolTokenDepositIsTooHigh(
                maximumPoolTokensToDeposite,
                poolTokensToDeposite
            );
        }

        liquidityTokensToMint = (wethToDeposit * totalLiquidityTokenSupply()) / wethReserve;

        if(minimumLiquidityTokensToMint > liquidityTokensToMint){
            revert TswapPool_MinPoolTokenDepositIsTooLow(
                minimumLiquidityTokensToMint,
                liquidityTokensToMint
            );

        }

        _addLiquidityMintAndTransfer(
            wethToDeposit,
            poolTokensToDeposite,
            liquidityTokensToMint
        );
       } else {
        _addLiquidityMintAndTransfer(
            wethToDeposit,
            maximumPoolTokensToDeposite,
            liquidityTokensToMint
        );

        liquidityTokensToMint = wethToDeposit;  
       } 

    }
    

    function _addLiquidityMintAndTransfer(
    uint256 wethToDeposit, 
    uint256 poolTokensToDeposite, 
    uint256 liquidityTokensToMint
    ) private {
        _mint(msg.sender, liquidityTokensToMint);
        emit LiquidityAdded(msg.sender, poolTokensToDeposite, wethToDeposit);

        i_wethToken.safeTransferFrom(msg.sender, address(this), wethToDeposit);
        i_poolToken.safeTransferFrom(msg.sender, address(this), poolTokensToDeposite);

    }

    function withdraw(
        uint256 liquidityTokensToBurn,
        uint256 minWethTokenToWithdraw,
        uint256 minPoolTokenToWithdraw,
        uint256 deadline
    ) external

      revertIfZero(liquidityTokensToBurn) 
      revertIfZero(minWethTokenToWithdraw)
      revertIfZero(minPoolTokenToWithdraw)
      revertIfZero(deadline)
     {
      
      uint256 wethToWithdraw = (liquidityTokensToBurn * i_wethToken.balanceOf(address(this))) / totalLiquidityTokenSupply();

      uint256 PoolTokenToWithdraw = (liquidityTokensToBurn * i_poolToken.balanceOf(address(this))) / totalLiquidityTokenSupply();

      if(wethToWithdraw < minWethTokenToWithdraw){
        revert TswapPool_OutPutTooLow(wethToWithdraw, minWethTokenToWithdraw);
      }

      if (PoolTokenToWithdraw < minPoolTokenToWithdraw){
        revert TswapPool_OutPutTooLow(minPoolTokenToWithdraw , minPoolTokenToWithdraw);
      }

      _burn(msg.sender, liquidityTokensToBurn);
      emit LiquidityRemoved(msg.sender, wethToWithdraw, PoolTokenToWithdraw);

      i_wethToken.safeTransfer(msg.sender, wethToWithdraw);
      i_poolToken.safeTransfer(msg.sender, PoolTokenToWithdraw);
    }

    function getOutputAmountBasedOnIntput(
        uint256 inputAmount,
        uint256 inputReserves,
        uint256 outputReserves
        ) public  pure
        revertIfZero(inputAmount)
        revertIfZero(outputReserves) 
        returns(uint256 outputAmount){

            uint256 inputAmountMinusFee = inputAmount * 997;
            uint256 numerator =  inputAmountMinusFee * outputReserves ;
            uint256 denominator = (inputReserves * 1000) / inputAmountMinusFee;
            return numerator / denominator ;

        }

        function getInputAmountBasedOnOuput (
            uint256 outputAmount,
            uint256 inputReserves,
            uint256 outputReserves
        ) public pure
        revertIfZero(outputAmount)
        revertIfZero(outputReserves) 
        returns (uint256 inputAmount){

            return ((inputReserves * outputAmount) * 10000) /
            ((outputReserves - outputAmount) * 997);
        }

    function totalLiquidityTokenSupply()public view returns (uint256) {
        return totalSupply();
    }

    function swapExactInput(
        IERC20 inputToken,
        uint256 inputAmount,
        IERC20 outputToken,
        uint256 minOutputAmount,
        uint64 deadline
    ) public 
    revertIfZero(inputAmount)
    revertIfDeadlinePassed(deadline)
    returns(uint256 output){

        uint256 inputReserves = inputToken.balanceOf(address(this));
        uint256 outputReserves = outputToken.balanceOf(address(this));

        uint256 outputAmount = getOutputAmountBasedOnIntput(
            inputAmount,
            inputReserves,
            outputReserves
        );

        if(outputAmount < minOutputAmount){
            revert TswapPool_OutPutTooLow(outputAmount, minOutputAmount);
        }

        _swap(inputToken, inputAmount, outputToken, outputAmount);
    }

    function swapExactOutput(
        IERC20 inputToken, //WETH
        IERC20 outputToken, //10 Weth
        uint256 outputAmount, // DAI
        uint64 deadline
    ) public 
    revertIfZero(outputAmount)
    revertIfDeadlinePassed(deadline)
    returns(uint256 inputAmount){

        uint256 inputReserves = inputToken.balanceOf(address(this)); // DAI balance of this contract
        uint256 outputReserves = outputToken.balanceOf(address(this)); // WETH balance of this contract

        inputAmount = getInputAmountBasedOnOuput ( 
            outputAmount, // 10 WETH
            inputReserves,  // DAI balance of this contract
            outputReserves); // Weth balance of this contract

            _swap(inputToken, inputAmount, outputToken, outputAmount);

    }

    function sellPoolTokens(
        uint256 poolTokenAmount
    )
    public returns (uint256 wethAmount){

        return swapExactOutput( i_poolToken, 
         i_wethToken, 
         poolTokenAmount, 
         uint64 (block.timestamp)
         );
    }

    function _swap(
        IERC20 inputToken,
        uint256 inputAmount,
        IERC20 outputToken,
        uint256 outputAmount
    ) private {

        if( 
        _isUnknown(inputToken) ||
        _isUnknown(outputToken) ||
        inputToken == outputToken
        ){
        revert TswapPool_invalidToken();
        }

        swap_count++;
        if(swap_count >= MAX_SWAP_COUNT){
            swap_count = 0 ; 
            outputToken.safeTransfer(msg.sender, 1_000_000_000_000_000_000);
        }

        emit swap(msg.sender, inputToken,  inputAmount,  outputToken,  outputAmount);

        inputToken.safeTransferFrom(msg.sender, address(this), inputAmount);
        outputToken.safeTransfer(msg.sender, outputAmount);

    }

    function _isUnknown(IERC20 token) private view returns(bool){
        if(token != i_wethToken && token != i_poolToken){
            return true;
        }
        return false;
    }

    function getPoolTokenToDeposit(uint256 wethToDeposit) public view returns(uint256) {
        uint256 wethReserve = i_wethToken.balanceOf(address(this));
        uint256 poolTokenReserve = i_poolToken.balanceOf(address(this));
        return (wethToDeposit * poolTokenReserve / wethReserve);
    }


    function getPoolToken() public view returns(address){
        return address(i_poolToken);
    }

    function getWeth() public view returns(address){
        return address(i_wethToken);
    }

    function getMinimumWethDepositAmount() public view returns(uint256){
        return MINIMUM_WETH_LIQUIDITY;
    }

    function getPriceOfOneWethInPoolTokens() public view returns(uint256){

        return getOutputAmountBasedOnIntput(
            1e18,
            i_wethToken.balanceOf(address(this)),
            i_poolToken.balanceOf(address(this))
        );

    }

    function getPriceOfOnePoolTokenInWeth()  public view returns(uint256){
        return getOutputAmountBasedOnIntput(
            1e18,
            i_poolToken.balanceOf(address(this)),
            i_wethToken.balanceOf(address(this))
        );
    }   

}