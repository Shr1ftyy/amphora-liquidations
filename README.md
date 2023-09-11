# Amphora Liquidator
Liquidator bot for [Amphora Finance](https://amphorafinance.com/).

## Running
``` shell
node scripts/liquidate.js
```

## Tests
``` shell
yarn test
```

## Openzepplin Defender IntegrationA
Create a relay and an Autotask. Assign the Autotask to that Relay and copy the code from 
[liquidate.js](./scripts/liquidate.js) into the code section of the Autotask and run it.

See more in the docs [here](https://docs.openzeppelin.com/defender/v1/autotasks).
