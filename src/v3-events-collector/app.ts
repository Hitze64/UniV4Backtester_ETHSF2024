import {
  IUniswapV3PoolEvents__factory,
} from '@aperture_finance/uniswap-v3-automation-sdk';
import { ExtractAbiEventNames } from 'abitype';
import converter from 'convert-csv-to-json';
import { appendFileSync, writeFileSync } from 'fs';
import {
  Address,
  Log,
  createPublicClient,
  getAddress,
  webSocket,
} from 'viem';
import {
  mainnet
} from 'viem/chains';

type UniV3PoolEventsAbi = typeof IUniswapV3PoolEvents__factory.abi;
type UniV3PoolScannedEvent = Log<
  /*TQuantity=*/ bigint,
  /*TIndex=*/ number,
  /*TPending=*/ false,
  /*TAbiEvent=*/ undefined,
  /*TStrict=*/ false,
  UniV3PoolEventsAbi,
  ExtractAbiEventNames<UniV3PoolEventsAbi>
>;

const UNIV3_FACTORY_DEPLOYMENT_BLOCK = 12369621;
const EVENT_SCAN_BLOCK_CHUNK_SIZE = 10000;

type EventCollectorState = {
  lastCompletedBlock: number;
  pool: Address;
};

const viemPublicClient =
  createPublicClient({
    chain: mainnet,
    transport: webSocket('wss://ethereum.publicnode.com'),
  });

async function writeEventsToCsv(
  events: UniV3PoolScannedEvent[],
) {
  for (const event of events) {
    if (event.eventName !== 'Mint' && event.eventName !== 'Burn' && event.eventName !== 'Swap') continue;
    const block = await viemPublicClient.getBlock({
      blockNumber: event.blockNumber
    });
    const args = event.args as any;
    appendFileSync('../data/univ3-wbtc-weth-0.3-events.csv', `${event.eventName},${block.timestamp},${event.eventName === 'Burn' ? -args.amount : args.amount ?? ''},${args.tickLower ?? ''},${args.tickUpper ?? ''},${args.amount0 ?? ''},${args.amount1 ?? ''}\n`);
  }
}

// Fetches events for the specified pools within the specified block range with retries.
// Since requests may fail due to various reasons, e.g. when the number of events within the specified block range is too large (e.g. 10000 events),
// we retry with a smaller block range (half of the previous request) until we get a successful response.
// If the block range is already small enough, i.e. at most 5 blocks, we give up and throw the error.
async function getContractEventsWithRetries(
  pool: Address,
  fromBlock: bigint,
  desiredToBlock: bigint,
): Promise<{
  events: UniV3PoolScannedEvent[];
  actualToBlock: bigint;
}> {
  try {
    const events = await viemPublicClient.getContractEvents({
      address: pool,
      abi: IUniswapV3PoolEvents__factory.abi,
      fromBlock: fromBlock,
      toBlock: desiredToBlock,
    });
    return {
      events,
      actualToBlock: desiredToBlock,
    };
  } catch (err) {
    if (desiredToBlock - fromBlock + 1n <= 5n) throw err;
    // Retry with the first half of the previous block range.
    const reducedRangeToBlock = (fromBlock + desiredToBlock) >> 1n;
    console.info(
      `getContractEvents failed with error: ${err}`,
    );
    console.info(
      `Retrying getContractEvents(fromBlock = ${fromBlock}, toBlock = ${desiredToBlock}) with reduced block range: [${fromBlock}, ${reducedRangeToBlock}]...`,
    );
    await new Promise((resolve) => setTimeout(resolve, 500));
    return await getContractEventsWithRetries(
      pool,
      fromBlock,
      reducedRangeToBlock,
    );
  }
}

async function getBatchUpperBlockNumber(
  state: EventCollectorState,
): Promise<{
  toBlock: number;
  latestBlock: number | undefined;
}> {
  let latestBlock = Number(await viemPublicClient.getBlockNumber());
  return {
    toBlock: Math.min(
      latestBlock,
      state.lastCompletedBlock + EVENT_SCAN_BLOCK_CHUNK_SIZE,
    ),
    latestBlock,
  };
}

// Fetches a single batch of events from the speicified state, and update the state afterwards.
async function fetchSingleBatchOfEvents(
  state: EventCollectorState,
) {
  const fromBlock = BigInt(state.lastCompletedBlock + 1);
  const { toBlock: desiredToBlock, latestBlock } = await getBatchUpperBlockNumber(
    state,
  );
  const { events, actualToBlock } = await getContractEventsWithRetries(
    state.pool,
    fromBlock,
    BigInt(desiredToBlock),
  );
  console.info(
    `Fetched ${events.length} events from block ${fromBlock} to ${actualToBlock}.`,
  );
  await writeEventsToCsv(events);

  // Update state.
  state.lastCompletedBlock = Number(actualToBlock);

  // Sleep for 5 mins if this batch synced to the latest block.
  if (latestBlock !== undefined && actualToBlock === BigInt(latestBlock)) {
    console.info(
      `Synced to the latest block (number ${actualToBlock}). Sleeping for 5 mins...`,
    );
    await new Promise((resolve) => setTimeout(resolve, 5 * 60 * 1000));
  }
}

async function fetchUniV3PoolEvents() {
  const state: EventCollectorState = {
    lastCompletedBlock: UNIV3_FACTORY_DEPLOYMENT_BLOCK,
    // UniV3 WBTC-WETH 0.3% pool on mainnet.
    pool: getAddress('0xCBCdF9626bC03E24f779434178A73a0B4bad62eD'),
  };

  // Fetch pool events in batches indefinitely.
  while (true) {
    await fetchSingleBatchOfEvents(state);
  }
}

/*
    int amount;
    int amount0;
    int amount1;
    uint8 eventType; // 0: MintBurn, 1: Swap
    int tickLower;
    int tickUpper;
    uint128 unixTimestamp;
*/

function convertCsvToJson() {
  const rawEvents = converter.fieldDelimiter(',').getJsonFromCsv('../data/univ3-wbtc-weth-0.3-events.csv');
  const processedEvents = rawEvents.map((event) => {
    return {
      amount: Number(event.amount),
      amount0: Number(event.amount0),
      amount1: Number(event.amount1),
      eventType: event.eventName === 'Swap' ? 1 : 0,
      tickLower: Number(event.tickLower),
      tickUpper: Number(event.tickUpper),
      unixTimestamp: Number(event.unixTimestamp),
    };
  });
  writeFileSync('../data/univ3-wbtc-weth-0.3-events.json', JSON.stringify(processedEvents));
}

convertCsvToJson();
