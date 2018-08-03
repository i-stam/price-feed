const PriceFeed = artifacts.require('./PriceFeed.sol');

contract('PriceFeed', accounts => {

  it('should get the TKN / ETH pairing from the Cryptocompare web api.', async () => {
    const priceFeed = await PriceFeed.new()
    let response = await priceFeed.updateRate()

    // Confirm new oraclize query event emitted
    let log = response.logs[0]
    assert.equal(log.event, 'LogNewOraclizeQuery', 'LogNewOraclizeQuery not emitted.')
    assert.equal(log.args.description, 'Oraclize query was sent, standing by for the answer...', 'Incorrect description emitted.')

    // Wait for the callback to be invoked by oraclize and the event to be emitted
    const logNewPriceWatcher = promisifyLogWatch(priceFeed.LogRateUpdated({ fromBlock: 'latest' }));

    log = await logNewPriceWatcher;
    assert.equal(log.event, 'LogRateUpdated', 'LogRateUpdated not emitted.')
    assert.notEqual(log.args.price,'ERROR', 'Error in updating price.')

    console.log('Success! Current price is: ' + log.args.price + ' TKN/ETH') //log.args.price.toNumber() / 10e5
  });
});

/**
 * Helper to wait for log emission.
 * @param  {Object} _event The event to wait for.
 */
function promisifyLogWatch(_event) {
  return new Promise((resolve, reject) => {
    _event.watch((error, log) => {
      _event.stopWatching();
      if (error !== null)
        reject(error);

      resolve(log);
    });
  });
}
