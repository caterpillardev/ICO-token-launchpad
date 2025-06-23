# ICO-Launchpad
## ICO contract functions to use in UI

### View functions icoParams(uint256 id), icoState(uint256 id), getICO(uint256 id) returns structures


```Solidity
    struct VestingParams {
        uint256 unlockPercentage; // percentage (with 2 decimals) of initially unlocked token. I.e. 500 means 5% unlocked and 95% will go to vesting, 10000 means 100% unlocked (vesting will not be used)
        uint256 cliffPeriod;    // cliff period (in seconds). The first release will be after this time.
        uint256 vestingPercentage;        // percentage (with 2 decimals) of locked tokens will be unlocked every interval I.e. 500 means 5% per vestingInterval
        uint256 vestingInterval;     // interval (in seconds) of vesting (i.e. 2592000 = 30 days)        
    }

    struct ICOParams {
        address token;      // ICO token
        address paymentToken;   // if address(0) - native coin
        uint256 amount;     // amount of token to sell
        uint256 startPrice; // price of 1 token in paymentTokens
        uint256 endPrice;   // if 0 then price is fixed, else price grows liner from startPrice to endPrice based on sold tokens.
        uint256 startDate; // timestamp when ICO starts. The date must be in future.
        uint256 endDate;   // timestamp when ICO ends, if 0 then ICO will be active until sell all tokens
        uint256 bonusReserve;  // amount of tokens that will be used for bonus. Bonus will be paid until it's available
        uint256 bonusPercentage;  // percent of bonus (with 2 decimals) which will be added to bought amount. I.e. 2500 = 25%
        uint256 bonusActivator;   // percent of total ICO tokens that should be bought to activate bonus (with 2 decimals). I.e. 1000 = 10% 
        // Let say total amount of tokens on this ICO is 1,000,000, so to receive bonus a user should buy at least 100,000 tokens at ones (10%) 

        VestingParams vestingParams;   // parameters of vesting
    }


    struct ICOState {
        address ICOOwner;   //  address of ICO owner (creator) who will receive payment tokens
        uint8 icoTokenDecimals; // number decimals of ICO token (get from token.decimals())
        address vestingContract;    //  address of vesting contract
        bool isClosed;      // ICO is closed
        uint256 totalSold;  // total amount of sold tokens
        uint256 totalReceived;   // total amount received (in paymentToken)
    }
```

### View function getValue
```Solidity
    // returns value of paymentToken to pay for ICO tokens amount
    function getValue(
        uint256 id,     // ICO id
        uint256 amount  // amount of ICO tokens to buy
    ) public view returns(
        uint256 availableAmount, // amount of available tokens (in case if ICO has less tokens then requested)
        uint256 value // value that user have to pay in paymentToken for availableAmount
    );
```

### `createICO`

```Solidity
    // create new ICO. User should approve ICO tokens (amount + bonusReserve)
    function createICO(ICOParams memory params) external;

    // emit 
    event ICOCreated(uint256 ICO_id, address token, address owner, address vestingContract);
```

### `buyToken`

```Solidity
    // Buy ICO tokens. The value of paymentToken should be approved to ICO contract
    function buyToken(
        uint256 id,     // ICO id
        uint256 amountToBuy,    // amount of token to buy
        address buyer           // buyer address
    ) external payable;

    //emit
    event BuyToken(address buyer, uint256 ICO_id, uint256 amountPaid, uint256 amountBought, uint256 bonus);
```

Allow users to buy tokens from ICO. The `amount` parameter is an amount that user wants to buy.
- user should `approve` tokens for ICO contract before call function `buyToken`.

### `closeICO`
```Solidity
    // allow ICO owner to close ICO and get back unsold tokens
    function closeICO(uint256 id) external;

    // emit
    event CloseICO(uint256 ICO_id, address owner, address token, uint256 refund);
```

## Vesting contract functions to use in UI

### View function `getUnlockedAmount`

```Solidity
    function getUnlockedAmount(address beneficiary) public view returns(uint256 unlockedAmount, uint256 lockedAmount, uint256 nextUnlock);
```

Returns amount of tokens that user (beneficiary) can claim. Show this amount in UI.

### `claim` and `claimBehalf`

```Solidity
    // claim unlocked tokens by msg.sender
    function claim() external;

    // claim unlocked tokens behalf beneficiary
    function claimBehalf(address beneficiary) public;
```

This function claims unlocked tokens for user.


# Deployed

## Callisto
- Launchpad proxy (use this contract for interaction): https://explorer.callistodao.org/address/0xbeF7680572692487F8ba88a5443f9Be8AE31Ba89/read-proxy#address-tabs
- Launchpad implementation (get ABI from it): https://explorer.callistodao.org/address/0x3eBCEE85AcA5e4bBd98D38310218CdA47055F240/contracts#address-tabs
- Vesting implementation (get ABI from it): https://explorer.callistodao.org/address/0x1BD1E3C976aEceB5947f9883a8FB31adE962431E/contracts#address-tabs

- TokensFactory (allow to create token contracts for testing) https://explorer.callistodao.org/address/0x7b9c5FFa911CE7b3F4647bB29277dB68295A3e52/write-contract#address-tabs
`function  createToken1B(string name)` create net token with `name` and mint 1,000,000,000 token to caller.
