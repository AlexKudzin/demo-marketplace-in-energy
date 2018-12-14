## A guide to demoing the contract

### Install dependencies

Before the first run, dependencies need to be installed for the test scripts and the status viewer.

```shell
cd scripts/
npm install
```

```shell
cd scripts/status
npm web3 install
```

### Run a deterministic TestRPC session

```shell
testrpc -d
```

### Deploy the contract

```shell
truffle migrate --reset
```

### Run the issuer script that issues smart meter ownerships

```shell
cd scripts/
node issuer.js
```

### Open the status view in browser

cd scripts/status
google-chrome index.html` or another browser of choice, ie firefox index.html.

### Create sell offers

Change the optional index argument to create different pre-populated offers [1349-1358] see offer-objects.js. The default behavior is to choose the offer at index 0.
```shell
cd scripts
node offer [<index>] 

```

### Accept offers as a buyer

```shell
cd scripts
node acceptoffer [<index>]
Defult range to add into brackets is 1349 - 1358, this is the Contract ID in offer-objects.js
```

### Send reports from smart meters (or wait until the report deadline)

```shell
cd scripts
node sellerreport [<index>]
node buyerreport [<index>]
Defult range to add into brackets is 1349 - 1358, this is the Contract ID in offer-objects.js
```

### Withdraw money

```shell
cd scripts
node withdraw [<index>]
Defult range to add into brackets is 1349 - 1358, this is the Contract ID in offer-objects.js
```
