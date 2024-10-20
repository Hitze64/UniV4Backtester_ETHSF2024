// SPDX-License-Identifier: MIT
// $ forge script UniV4Backtester --fork-url https://eth-sepolia.g.alchemy.com/v2/0123456789ABCDEFGHIJKLMNOPQRSTUV --fork-block-number 6907299
pragma solidity >=0.8.0;

import "./ICreate2Deployer.sol";
import "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {Test, console} from "forge-std/Test.sol";
import {PoolEvent, PoolEvents} from "./SUniV4Backtester.sol";
import {WBTC, WETH} from "./Token.sol";
// import {AutoCompound} from "./hooks/AutoCompound.sol";
import {NoopHook} from "./hooks/NoopHook.sol";
import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IHooks} from "lib/v4-periphery/lib/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "lib/v4-periphery/lib/v4-core/src/libraries/Hooks.sol";
import {TickMath} from "lib/v4-periphery/lib/v4-core/src/libraries/TickMath.sol";
import {Currency} from "lib/v4-periphery/lib/v4-core/src/types/Currency.sol";
import {IPermit2} from "lib/v4-periphery/lib/permit2/src/interfaces/IPermit2.sol";
import {PoolKey} from "lib/v4-periphery/lib/v4-core/src/types/PoolKey.sol";
import {PoolManager} from "lib/v4-periphery/lib/v4-core/src/PoolManager.sol";
import {IPoolManager} from "lib/v4-periphery/lib/v4-core/src/interfaces/IPoolManager.sol";
import {PoolSwapTest} from "lib/v4-periphery/lib/v4-core/src/test/PoolSwapTest.sol";
import {PositionManager} from "lib/v4-periphery/src/PositionManager.sol";
import {IPositionManager} from "lib/v4-periphery/src/interfaces/IPositionManager.sol";
import {Actions} from "lib/v4-periphery/src/libraries/Actions.sol";
import {HookMiner} from "lib/v4-template/test/utils/HookMiner.sol";
import {SafeCallback} from "lib/v4-periphery/src/base/SafeCallback.sol";

contract UniV4Backtester is Test {

    mapping(string => bool) private isTicksExist;
    mapping(string => uint) private ticksToTokenId;
    uint nextTokenId = 0;

    // Returns mint/swap/burn events from UniV3 pool since pool creation until endDate.
    function getPoolEvents(
        uint128 endDate
    ) internal view returns (PoolEvent[] memory) {
        string memory json = vm.readFile("src/data/univ3-wbtc-weth-0.3-events.json");
        bytes memory data = vm.parseJson(json);
        PoolEvents memory poolEvents = abi.decode(data, (PoolEvents));
        uint256 length = 0;
        while (length < poolEvents.events.length && poolEvents.events[length].unixTimestamp <= endDate) {
            length++;
        }
        PoolEvent[] memory events = new PoolEvent[](length);
        for (uint256 i = 0; i < length; i++) {
            events[i] = poolEvents.events[i];
        }
        return events;
    }

    function run() public {
        uint128 MAX_UINT128 = 2**128 - 1;
        uint128 FAR_FUTURE_TIMESTAMP = 1800000000;
        address zeroAddress = 0x0000000000000000000000000000000000000000;
        address create2DeployerAddress = 0x13b0D85CcB8bf860b6b79AF3029fCA081AE9beF2; // https://github.com/pcaversaccio/create2deployer
        address hookAddress = 0xF29c677034a08748442b3E85368484eA4b760000; // Set as 0 to mine a new one
        address poolManagerAddress = 0x8C4BcBE6b9eF47855f97E675296FA3F6fafa5F1A; // https://docs.uniswap.org/contracts/v4/deployments
        address poolSwapTestAddress = 0xe49d2815C231826caB58017e214Bed19fE1c2dD4; // https://docs.uniswap.org/contracts/v4/deployments
        address positionManagerAddress = 0x1B1C77B606d13b09C84d1c7394B96b147bC03147; // https://docs.uniswap.org/contracts/v4/deployments
        address whaleAddress = 0x8EB8a3b98659Cce290402893d0123abb75E3ab28;
        address permit2Address = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

        // No need to deploy token0, using native currency = eth = address(0)
        console.log("Before deploying Token0, MAX_UINT128=", MAX_UINT128, ", and when typecasting negative to unsigned=", uint256(int256(-1)));
        WBTC token0 = new WBTC();
        console.log("After deploying Token0@", address(token0), ", token0.balanceOf(address(this))=", token0.balanceOf(address(this)));

        // Deploy token1
        console.log("Before deploying Token1, MAX_UINT128=", MAX_UINT128);
        WETH token1 = new WETH();
        console.log("After deploying Token1@", address(token1), ", token1.balanceOf(address(this))=", token1.balanceOf(address(this)));

        // Deal to whale
        console.log("Before dealing token0");
        deal(address(token0), whaleAddress, MAX_UINT128);
        console.log("After dealing token0");
        deal(address(token1), whaleAddress, MAX_UINT128);
        console.log("After dealing token1");

        // Hook info
        if (hookAddress == address(0)) {
            uint160 flags = 0;
            bytes memory constructorArgs = abi.encode(poolManagerAddress);
            (address minedHookAddress, ) = HookMiner.find(create2DeployerAddress, flags, type(NoopHook).creationCode, constructorArgs);
            hookAddress = minedHookAddress;
            console.log("Finished Mining Hook Address, hookAddress=", hookAddress);
        }
        deployCodeTo("NoopHook.sol", abi.encode(poolManagerAddress), hookAddress);
        NoopHook noopHook = NoopHook(hookAddress);
        console.log("After deploying Hook@", address(noopHook));

        // Pool info
        PoolManager poolManager = PoolManager(poolManagerAddress);
        // set the router address
        PoolSwapTest swapRouter = PoolSwapTest(address(poolSwapTestAddress));
        // slippage tolerance to allow for unlimited price impact
        uint160 MIN_PRICE_LIMIT = TickMath.MIN_SQRT_PRICE + 1;
        uint160 MAX_PRICE_LIMIT = TickMath.MAX_SQRT_PRICE - 1;
        console.log("MIN_PRICE_LIMIT=", MIN_PRICE_LIMIT, ", MAX_PRICE_LIMIT=", MAX_PRICE_LIMIT);
        uint160 initialSqrtPriceX96 = 31703474972180322262301571401662639;
        Currency currency0 = Currency.wrap(address(token0)); // native eth on sepolia.unichain
        Currency currency1 = Currency.wrap(address(token1)); // deployed usdc on sepolia.unichain
        uint24 fee = 3000;
        int24 tickSpacing = 60;
        PoolKey memory poolKey = PoolKey(currency0, currency1, fee, tickSpacing, IHooks(address(zeroAddress)));
        console.log("Before initializing pool, address(poolManager).code.length=", address(poolManager).code.length, ", address(poolSwapTestAddress).code.length=", address(poolSwapTestAddress).code.length);
        poolManager.initialize(poolKey, initialSqrtPriceX96);
        console.log("After initialize pool");

        // Position info
        PositionManager positionManager = PositionManager(positionManagerAddress);
        nextTokenId = positionManager.nextTokenId();
        uint128 positionStartDate = FAR_FUTURE_TIMESTAMP;
        uint128 positionInitialLiquidity = 1234567890;
        int positionInitialTickLower = 253320;
        int positionInitialTickUpper = 264600;
        console.log("After getting position manager, address(poolManager).code.length=", address(positionManager).code.length);

        // Approve
        IPermit2 permit2 = IPermit2(permit2Address);
        vm.prank(whaleAddress);
        token0.approve(permit2Address, MAX_UINT128);
        vm.prank(whaleAddress);
        token1.approve(permit2Address, MAX_UINT128);
        vm.prank(whaleAddress);
        permit2.approve(address(token0), address(positionManager), type(uint160).max, type(uint48).max);
        vm.prank(whaleAddress);
        permit2.approve(address(token1), address(positionManager), type(uint160).max, type(uint48).max);
        (uint160 amount0, uint48 expiration0, uint48 nonce0) = permit2.allowance(whaleAddress, address(token0), address(positionManager));
        (uint160 amount1, uint48 expiration1, uint48 nonce1) = permit2.allowance(whaleAddress, address(token1), address(positionManager));
        console.log(string.concat(string.concat(string.concat(string.concat(string.concat(string.concat(string.concat(string.concat(string.concat(string.concat("After approving whale, permit2's allowance amount0=", Strings.toString(amount0), ", expiration0=", Strings.toString(expiration0), ", nonce0=", Strings.toString(nonce0), ", amount1=", Strings.toString(amount1), ", expiration1=", Strings.toString(expiration1), ", nonce1=", Strings.toString(nonce1))))))))))));
        ERC20(token0).approve(address(swapRouter), type(uint256).max);
        ERC20(token1).approve(address(swapRouter), type(uint256).max);

        // Get and loop through pool events
        PoolEvent[] memory poolEvents = getPoolEvents(FAR_FUTURE_TIMESTAMP);
        bool isPositionInitialized = false;
        console.log("tommyzhao num events", poolEvents.length);
        for (uint i = 0; i < 50; i++) {
            PoolEvent memory poolEvent = poolEvents[i];
            if (!isPositionInitialized && positionStartDate <= poolEvent.unixTimestamp) {
                // console.log(string.concat(string.concat(string.concat(string.concat(string.concat(string.concat(string.concat("Initializing position at unixTimestamp=", Strings.toString(poolEvents[i].unixTimestamp), ", positionInitialLiquidity=", Strings.toString(positionInitialLiquidity), ", tickLower=", Strings.toStringSigned(positionInitialTickLower), ", positionInitialTickUpper=", Strings.toStringSigned(positionInitialTickUpper)))))))));
                isPositionInitialized = true;
            }
            if (poolEvent.eventType == 0) {
                console.log(string.concat(string.concat(string.concat(string.concat(string.concat(string.concat(string.concat((poolEvent.amount >= 0 ? "Mint" : "Burn"), " at unixTimestamp=", Strings.toString(poolEvents[i].unixTimestamp), ", amount=", Strings.toStringSigned(poolEvent.amount), ", tickLower=", Strings.toStringSigned(poolEvent.tickLower), ", tickUpper=", Strings.toStringSigned(poolEvent.tickUpper)))))))));
                string memory ticks = string.concat(Strings.toStringSigned(poolEvent.tickLower), Strings.toStringSigned(poolEvent.tickUpper));
                uint256 tokenId = ticksToTokenId[ticks];
                // If ticks doesn't exist, then it has to be a mint operation
                if (!isTicksExist[ticks]) {
                    isTicksExist[ticks] = true;
                    tokenId = nextTokenId++;
                    ticksToTokenId[ticks] = tokenId;
                    // https://docs.uniswap.org/contracts/v4/quickstart/manage-liquidity/mint-position
                    bytes memory actions = abi.encodePacked(uint8(Actions.MINT_POSITION), uint8(Actions.SETTLE_PAIR));
                    bytes[] memory params = new bytes[](2);
                    params[0] = abi.encode(poolKey, int24(poolEvent.tickLower), int24(poolEvent.tickUpper), uint256(poolEvent.amount), MAX_UINT128, MAX_UINT128, whaleAddress, "");
                    params[1] = abi.encode(currency0, currency1);
                    // console.log(string.concat(string.concat(string.concat(string.concat(string.concat(string.concat(string.concat(string.concat(string.concat(string.concat(string.concat("Before modifyLiquidities, Actions.MINT_POSITION=", Strings.toString(Actions.MINT_POSITION), ", Actions.SETTLE_PAIR=", Strings.toString(Actions.SETTLE_PAIR), ", int24(poolEvent.tickLower)=", Strings.toStringSigned(int24(poolEvent.tickLower)), ", int24(poolEvent.tickUpper)=", Strings.toStringSigned(int24(poolEvent.tickUpper)), ", poolEvent.amount=", Strings.toString(uint256(poolEvent.amount)), ", MAX_UINT128=", Strings.toString(MAX_UINT128), ", whaleAddress=", Strings.toHexString(whaleAddress), ", actions.length=", Strings.toString(actions.length), ", params.length=", Strings.toString(params.length), ", params[0].length=", Strings.toString(params[0].length), ", params[1].length=", Strings.toString(params[1].length)))))))))))));
                    vm.prank(whaleAddress);
                    positionManager.modifyLiquidities(abi.encode(actions, params), uint256(FAR_FUTURE_TIMESTAMP));
                } else {
                    if (poolEvent.amount > 0) {
                        // https://docs.uniswap.org/contracts/v4/quickstart/manage-liquidity/increase-liquidity
                        bytes memory actions = abi.encodePacked(uint8(Actions.INCREASE_LIQUIDITY), uint8(Actions.SETTLE_PAIR));
                        bytes[] memory params = new bytes[](2);
                        params[0] = abi.encode(tokenId, uint256(poolEvent.amount), MAX_UINT128, MAX_UINT128, "");
                        params[1] = abi.encode(currency0, currency1);
                        vm.prank(whaleAddress);
                        positionManager.modifyLiquidities(abi.encode(actions, params), uint256(FAR_FUTURE_TIMESTAMP));
                    } else {
                        // https://docs.uniswap.org/contracts/v4/quickstart/manage-liquidity/decrease-liquidity
                        bytes memory actions = abi.encodePacked(uint8(Actions.DECREASE_LIQUIDITY), uint8(Actions.TAKE_PAIR));
                        bytes[] memory params = new bytes[](2);
                        params[0] = abi.encode(tokenId, uint256(-poolEvent.amount), 0, 0, "");
                        params[1] = abi.encode(currency0, currency1, whaleAddress);
                        vm.prank(whaleAddress);
                        positionManager.modifyLiquidities(abi.encode(actions, params), uint256(FAR_FUTURE_TIMESTAMP));
                        // bytes memory actions = abi.encodePacked(uint8(Actions.DECREASE_LIQUIDITY), uint8(Actions.CLEAR_OR_TAKE), uint8(Actions.CLEAR_OR_TAKE));
                        // bytes[] memory params = new bytes[](3);
                        // params[0] = abi.encode(tokenId, uint256(-poolEvent.amount), 0, 0, "");
                        // params[1] = abi.encode(currency0, MAX_UINT128);
                        // params[2] = abi.encode(currency1, MAX_UINT128);
                        // vm.prank(whaleAddress);
                        // positionManager.modifyLiquidities(abi.encode(actions, params), uint256(FAR_FUTURE_TIMESTAMP));
                    }
                }
            } else {
                // https://docs.uniswap.org/contracts/v4/quickstart/swap
                console.log(string.concat(string.concat(string.concat(string.concat(string.concat("Swap at unixTimestamp=", Strings.toString(poolEvents[i].unixTimestamp), ", amount0=", Strings.toStringSigned(poolEvent.amount0), ", amount1=", Strings.toStringSigned(poolEvent.amount1)))))));
                bool zeroForOne = poolEvent.amount0 > 0;
                IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
                    zeroForOne: zeroForOne,
                    amountSpecified: int256(zeroForOne ? poolEvent.amount0 : poolEvent.amount1),
                    sqrtPriceLimitX96: zeroForOne ? MIN_PRICE_LIMIT : MAX_PRICE_LIMIT // unlimited impact
                });
                // console.log("swap, amountSpecified=", params.amountSpecified);
                // console.log(zeroForOne);
                PoolSwapTest.TestSettings memory testSettings = PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false});
                // vm.prank(whaleAddress);
                // swapRouter.swap(poolKey, params, testSettings, "");
            }
            // console.log(poolManager.get)
        }
    }
}
