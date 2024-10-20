// SPDX-License-Identifier: MIT
// $ forge script UniV4Backtester --fork-url https://eth-sepolia.g.alchemy.com/v2/0123456789ABCDEFGHIJKLMNOPQRSTUV --fork-block-number 6907299
pragma solidity >=0.8.0;

import "./ICreate2Deployer.sol";
import "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {Test, console} from "forge-std/Test.sol";
import {PoolEvent, PoolEventType} from "./SUniV4Backtester.sol";
import {Token1} from "./Token1.sol";
// import {AutoCompound} from "./hooks/AutoCompound.sol";
import {NoopHook} from "./hooks/NoopHook.sol";
import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IHooks} from "lib/v4-periphery/lib/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "lib/v4-periphery/lib/v4-core/src/libraries/Hooks.sol";
import {Currency} from "lib/v4-periphery/lib/v4-core/src/types/Currency.sol";
import {PoolKey} from "lib/v4-periphery/lib/v4-core/src/types/PoolKey.sol";
import {PoolManager} from "lib/v4-periphery/lib/v4-core/src/PoolManager.sol";
import {IPoolManager} from "lib/v4-periphery/lib/v4-core/src/interfaces/IPoolManager.sol";
import {PositionManager} from "lib/v4-periphery/src/PositionManager.sol";
import {IPositionManager} from "lib/v4-periphery/src/interfaces/IPositionManager.sol";
import {Actions} from "lib/v4-periphery/src/libraries/Actions.sol";
import {HookMiner} from "lib/v4-template/test/utils/HookMiner.sol";
import {SafeCallback} from "lib/v4-periphery/src/base/SafeCallback.sol";

contract UniV4Backtester is Test {
// contract UniV4Backtester is Test, SafeCallback {
    // constructor() SafeCallback(IPoolManager(0x8C4BcBE6b9eF47855f97E675296FA3F6fafa5F1A)) {}

    // function _unlockCallback(bytes calldata data) internal override returns (bytes memory) {
    //     return "";
    // }

    // Returns mint/swap/burn events from UniV3 pool since pool creation until endDate.
    function getPoolEvents(
        PoolKey memory poolKey,
        uint128 endDate
    ) internal view returns (PoolEvent[] memory) {
        string memory json = vm.readFile("../data/univ3-wbtc-weth-0.3-events.json");
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
        address zeroAddress = 0x0000000000000000000000000000000000000000;
        address create2DeployerAddress = 0x13b0D85CcB8bf860b6b79AF3029fCA081AE9beF2; // https://github.com/pcaversaccio/create2deployer
        address hookAddress = 0xF29c677034a08748442b3E85368484eA4b760000; // Set as 0 to mine a new one
        address poolManagerAddress = 0x8C4BcBE6b9eF47855f97E675296FA3F6fafa5F1A; // https://docs.uniswap.org/contracts/v4/deployments
        address positionManagerAddress = 0x1B1C77B606d13b09C84d1c7394B96b147bC03147; // https://docs.uniswap.org/contracts/v4/deployments
        address whaleAddress = 0x8EB8a3b98659Cce290402893d0123abb75E3ab28;

        // No need to deploy token0, using native currency = eth = address(0)

        // Deploy token1
        console.log("Before deploying Token1");
        Token1 token1 = new Token1();
        console.log("After deploying Token1@", address(token1), ", token1.balanceOf(address(this))=", token1.balanceOf(address(this)));

        // Deal to whale
        console.log("Before dealing token0");
        deal(whaleAddress, MAX_UINT128);
        console.log("After dealing token0");
        deal(address(token1), whaleAddress, MAX_UINT128);
        console.log("After dealing token1");

        // Pool Manager
        PoolManager poolManager = PoolManager(poolManagerAddress);

        // Hook info
        if (hookAddress == address(0)) {
            uint160 flags = 0;
            bytes memory constructorArgs = abi.encode(poolManagerAddress);
            (address minedHookAddress, bytes32 salt) = HookMiner.find(create2DeployerAddress, flags, type(NoopHook).creationCode, constructorArgs);
            hookAddress = minedHookAddress;
            console.log("Finished Mining Hook Address, hookAddress=", hookAddress);
        }
        deployCodeTo("NoopHook.sol", abi.encode(poolManagerAddress), hookAddress);
        NoopHook noopHook = NoopHook(hookAddress);
        console.log("After deploying Hook@", address(hookAddress));

        // Pool info
        uint160 initialSqrtPriceX96 = 31703474972180322262301571401662639;
        Currency currency0 = Currency.wrap(0x0000000000000000000000000000000000000000); // native eth on sepolia.unichain
        Currency currency1 = Currency.wrap(address(token1)); // deployed usdc on sepolia.unichain
        uint24 fee = 3000;
        int24 tickSpacing = 60;
        PoolKey memory poolKey = PoolKey(currency0, currency1, fee, tickSpacing, IHooks(address(zeroAddress)));
        console.log("Before initializing pool, address(poolManager).code.length=", address(poolManager).code.length);
        poolManager.initialize(poolKey, 79228162514264337593543950336);
        // poolManager.unlock("");
        console.log("After initialize pool");

        // Position info
        PositionManager positionManager = PositionManager(positionManagerAddress);
        uint128 positionStartDate = 1800000000;
        uint128 positionInitialLiquidity = 123456789;
        int positionInitialTickLower = -198480;
        int positionInitialTickUpper = -198480;
        console.log("After getting position manager, address(poolManager).code.length=", address(positionManager).code.length);

        // Get and loop through pool events
        PoolEvent[] memory poolEvents = getPoolEvents(poolKey, 1800000000);
        bool isPositionInitialized = false;
        for (uint i = 0; i < 1; i++) {
            PoolEvent memory poolEvent = poolEvents[i];
            if (!isPositionInitialized && positionStartDate <= poolEvent.unixTimestamp) {
                console.log(string.concat(string.concat(string.concat(string.concat(string.concat(string.concat(string.concat("Initializing position at unixTimestamp=", Strings.toString(poolEvents[i].unixTimestamp), ", positionInitialLiquidity=", Strings.toString(positionInitialLiquidity), ", positionInitialTickLower=", Strings.toStringSigned(positionInitialTickLower), ", positionInitialTickUpper=", Strings.toStringSigned(positionInitialTickUpper)))))))));
                isPositionInitialized = true;
            }
            if (poolEvent.poolEventType == PoolEventType.MintBurn) {
                console.log(string.concat(string.concat(string.concat(string.concat(string.concat(string.concat(string.concat((poolEvent.amount >= 0 ? "Mint" : "Burn"), " at unixTimestamp=", Strings.toString(poolEvents[i].unixTimestamp), ", amount=", Strings.toStringSigned(poolEvent.amount), ", positionInitialTickLower=", Strings.toStringSigned(positionInitialTickLower), ", positionInitialTickUpper=", Strings.toStringSigned(positionInitialTickUpper)))))))));
                bytes memory actions = abi.encodePacked(Actions.MINT_POSITION, Actions.SETTLE_PAIR);
                bytes[] memory params = new bytes[](2);
                uint128 amountMax = uint128(uint256(poolEvent.amount));
                params[0] = abi.encode(poolKey, poolEvent.tickLower, poolEvent.tickUpper, uint256(poolEvent.amount), MAX_UINT128, MAX_UINT128, whaleAddress, "");
                params[1] = abi.encode(currency0, currency1);
                uint256 deadline = block.timestamp + 60;
                console.log(deadline);
                positionManager.modifyLiquidities(abi.encode(actions, params), deadline);
                // poolManager.mint(whaleAddress, 0, uint256(poolEvent.amount));
            } else if (poolEvent.poolEventType == PoolEventType.Swap) {
                console.log(string.concat(string.concat(string.concat(string.concat(string.concat("Swap at unixTimestamp=", Strings.toString(poolEvents[i].unixTimestamp), ", amount0=", Strings.toStringSigned(poolEvent.amount0), ", amount1=", Strings.toStringSigned(poolEvent.amount1)))))));
            }
        }
    }
}
