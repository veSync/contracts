# VeSync

This repo contains the contracts for VeSync, a ve(3,3) DEX on zkSync Era inspired by Velodrome Finance and Solidly.
## Testing

This repo uses both Foundry (for Solidity testing) and Hardhat (for deployment).

Foundry Setup (For Testing)

```ml
forge build
forge test
```

Hardhat Setup (For Deploy)

```ml
npm i
npx hardhat compile
```

## Deployment

This project's deployment process uses [Hardhat tasks](https://hardhat.org/guides/create-task.html). The scripts are found in `tasks/`.

There are several tasks for different stages of the project.

### IDO

Testnet

```
npx hardhat deploy:ido test --network zkTest
```

Mainnet

```
npx hardhat deploy:ido online --network zkMain
```

### IDO Claim Enabled

Testnet

```
npx hardhat deploy:enableClaim test --network zkTest
```

Mainnet

```
npx hardhat deploy:enableClaim online --network zkMain
```

### App Launch

Testnet

```
npx hardhat deploy:app test --network zkTest
```

Mainnet

```
npx hardhat deploy:app online --network zkMain
```

### Create Gauge for a pair

```
npx hardhat deploy:createGauge <pair address> --network <network>
```

## How to generate merkle proof for whitelist

1. Put addresses and sales cap ETH amount (in Wei) in `whitelist.json`

2. `ts-node ./scripts/whitelist-generator/main.ts -i ./whitelist.json`

3. Use the `root` variable from the output `proof.json` file to configure `TokenSale` contract.
