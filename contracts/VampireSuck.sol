// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.0;

import "./aave/FlashLoanReceiverBase.sol";
import "./aave/ILendingPoolAddressesProvider.sol";
import "./aave/ILendingPool.sol";

import "./interfaces/IMasterVampire.sol";
import "./interfaces/IDrainController.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IUniswapV2Pair.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

contract VampireSuck is FlashLoanReceiverBase {

    using SafeERC20 for IERC20;

    address constant masterVampire = 0xD12d68Fd52b54908547ebC2Cd77Ec6EbbEfd3099;
    address constant drainController = 0x2e813f2e524dB699d279E631B0F2117856eb902C;
    address constant uniswapRouter = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address constant aaveEth = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address constant weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant drc = 0xb78B3320493a4EFaa1028130C5Ba26f0B6085Ef8;
    address constant drcEth = 0x276E62C70e0B540262491199Bc1206087f523AF6;

    // Change this every deployment to help avoid detection
    uint constant freeHeadspace = 12967;

    address[] public ethToDrc;
    address[] public drcToEth;

    constructor(address _addressProvider) FlashLoanReceiverBase(_addressProvider) public {
        ethToDrc = [weth, drc];
        drcToEth = [drc, weth];
    }

    /**
        This function is called after your contract has received the flash loaned amount
     */
    function executeOperation(
        address _reserve,
        uint256 _amount,
        uint256 _fee,
        bytes calldata _params
    )
    external
    override
    {
        require(_amount <= getBalanceInternal(address(this), _reserve), "Failure 1");

        //
        // Your logic goes here.
        // !! Ensure that *this contract* has enough of `_reserve` funds to payback the `_fee` !!
        //

        (uint256[] memory pids, uint256 count) = abi.decode(_params, (uint256[], uint256));

        // Buy DRC
        IUniswapV2Router02 uniswap = IUniswapV2Router02(uniswapRouter);
        uniswap.swapExactETHForTokens{value:address(this).balance}(1, ethToDrc, address(this), block.timestamp);

        // Drain
        IMasterVampire dracula = IMasterVampire(masterVampire);
        for (uint i = 0; i < count; ++i) {
            dracula.drain(pids[i]);
        }

        // Sell DRC
        uint drcBalance = IERC20(drc).balanceOf(address(this));
        IERC20(drc).safeApprove(uniswapRouter, drcBalance);
        uniswap.swapExactTokensForETH(drcBalance, 1, drcToEth, address(this), block.timestamp);

        uint totalDebt = _amount.add(_fee);
        transferFundsBackToPoolInternal(_reserve, totalDebt);
    }

    function suck(uint256 amount, uint256[] calldata pids, uint256 count, uint112 expectedDrcReserves, bool shouldUpdatePrice) public payable onlyOwner {
        // Check reserves for front run
        IUniswapV2Pair drcEthPair = IUniswapV2Pair(drcEth);
        (uint112 drcReserves,,) = drcEthPair.getReserves();
        require(expectedDrcReserves <= drcReserves, "Error 02");

        if (shouldUpdatePrice) {
            IDrainController drainer = IDrainController(drainController);
            drainer.updatePrice();
        }

        bytes memory data = abi.encode(pids, count);

        ILendingPool lendingPool = ILendingPool(addressesProvider.getLendingPool());
        lendingPool.flashLoan(address(this), aaveEth, amount, data);
    }
}
