// SPDX-License-Identifier: No License (None)
pragma solidity 0.8.19;

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable {
    address internal _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () {
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function decimals() external view returns (uint8);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IVesting {
    function initialize(address owner_, address vestedToken_) external;
    function allocateTokens(
        address to, // beneficiary of tokens
        uint256 amount, // amount of token to lock on vesting contract
        uint256 cliffFinish,       // Timestamp (unix time) when starts vesting. First vesting will be at this time
        uint256 vestingPercentage,  // percentage (with 2 decimals) of tokens will be unlocked every interval (i.e. 10% per 30 days)
        uint256 vestingInterval     // interval (in seconds) of vesting (i.e. 30 days)
    ) external;
}

contract Launchpad is Ownable {
    address public vestingImplementation;

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

    mapping (address token => address vestingContract) public vestingContracts;
    mapping (uint256 ICOid => ICOParams) public icoParams;
    mapping (uint256 ICOid => ICOState) public icoState;
    uint256 public counter; // counter of ICOs
    bool public isPaused;    // launchpad is paused

    event BuyToken(address buyer, uint256 ICO_id, uint256 amountPaid, uint256 amountBought, uint256 bonus);
    event ICOCreated(uint256 ICO_id, address token, address owner, address vestingContract);
    event CloseICO(uint256 ICO_id, address owner, address token, uint256 refund);

    // initialize if use upgradable proxy
    function initialize(address vestingImplementation_) external {
        require(_owner == address(0), "Already init");
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
        vestingImplementation = vestingImplementation_;
    }

    modifier checkICO(uint256 id) {
        require(block.timestamp >= icoParams[id].startDate, "ICO is not started yet");
        require(block.timestamp <= icoParams[id].endDate || icoParams[id].endDate == 0, "ICO is finished");
        require(!icoState[id].isClosed, "ICO is closed");
        require(!isPaused, "Launchpad is paused");
        _;
    }

    // returns ICO details by ICO id
    function getICO(uint256 id) external view returns(ICOParams memory params, ICOState memory state) {
        params = icoParams[id];
        state = icoState[id];
    }

    // returns value of paymentToken to pay for tokens amount
    function getValue(
        uint256 id,     // ICO id
        uint256 amount  // amount of ICO tokens to buy
    ) public view returns(
        uint256 availableAmount, // amount of available tokens (in case if ICO has less tokens then requested)
        uint256 value // value that user have to pay in paymentToken for availableAmount
    ) {
        uint256 total = icoParams[id].amount;
        uint256 sold = icoState[id].totalSold;
        availableAmount = total - sold;
        if (amount < availableAmount) availableAmount = amount;
        uint256 endPrice = icoParams[id].endPrice;
        if (endPrice == 0) {    // fix price
            value = availableAmount * icoParams[id].startPrice / (10**icoState[id].icoTokenDecimals);
        } else {    // liner growing price
            uint256 startPrice = icoParams[id].startPrice;
            uint256 currentPrice = startPrice + ((endPrice - startPrice) * sold / total);
            endPrice = startPrice + ((endPrice - startPrice) * (sold + availableAmount) / total);   // price after purchase
            value = availableAmount * (currentPrice + endPrice) / (2 * 10**icoState[id].icoTokenDecimals);
        }
    }

    // create new ICO. User should approve ICO tokens (amount + bonusReserve)
    function createICO(ICOParams memory params) external {
        safeTransferFrom(params.token, msg.sender, address(this), params.amount + params.bonusReserve);
        uint256 id = counter;
        ++counter;
        icoParams[id] = params;
        icoState[id].ICOOwner = msg.sender;
        icoState[id].icoTokenDecimals = IERC20(params.token).decimals();

        require(params.vestingParams.unlockPercentage <= 10000, "Incorrect unlockPercentage");
        address vc;
        if (params.vestingParams.unlockPercentage < 10000) {
            // use vesting
            vc = vestingContracts[params.token];
            if(vc == address(0)) {
                vc = clone(vestingImplementation);
                IVesting(vc).initialize(msg.sender, params.token);
                vestingContracts[params.token] = vc;
            }
            icoState[id].vestingContract = vc;
        }
        emit ICOCreated(id, params.token, msg.sender, vc);
    }

    // Buy ICO tokens. The value of paymentToken should be approved to ICO contract
    function buyToken(
        uint256 id,     // ICO id
        uint256 amountToBuy,    // amount of token to buy
        address buyer           // buyer address
    ) external payable checkICO(id) {
        require(buyer != address(0), "Incorrect buyer");
        uint256 amountToPay;
        (amountToBuy, amountToPay) = getValue(id, amountToBuy);
        require(amountToBuy != 0, "sold out");

        ICOParams storage p = icoParams[id];
        ICOState storage s = icoState[id];
        address paymentToken = p.paymentToken;
        if(paymentToken == address(0)) {    // pay with native coin
            require(msg.value >= amountToPay, "Low payment");
            if (msg.value > amountToPay) safeTransferETH(msg.sender, msg.value - amountToPay);  // return rest
            safeTransferETH(s.ICOOwner, amountToPay);
        } else {    // pay with tokens
            safeTransferFrom(paymentToken, msg.sender, s.ICOOwner, amountToPay);
        }
        s.totalReceived += amountToPay;
        s.totalSold += amountToBuy;

        // calculate bonus
        uint256 bonus;
        {
        uint256 bonusReserve = p.bonusReserve;
        if (bonusReserve != 0) {
            if(p.amount * p.bonusActivator / 10000 <= amountToBuy) {
                bonus = amountToBuy * p.bonusPercentage / 10000;
                if (bonusReserve < bonus) bonus = bonusReserve;
                p.bonusReserve -= bonus;
            }
        }
        }

        uint256 unlockedAmount = amountToBuy + bonus;
        if(s.vestingContract != address(0)) {
            // set vesting
            uint256 cliffFinish = block.timestamp + p.vestingParams.cliffPeriod;
            unlockedAmount = unlockedAmount * p.vestingParams.unlockPercentage / 10000;
            uint256 lockedAmount = amountToBuy + bonus - unlockedAmount;
            if (lockedAmount != 0) {
                safeApprove(p.token, s.vestingContract, lockedAmount);
                IVesting(s.vestingContract).allocateTokens(buyer, lockedAmount, cliffFinish, p.vestingParams.vestingPercentage, p.vestingParams.vestingInterval);
            }
        }
        safeTransfer(p.token, buyer, unlockedAmount);
        emit BuyToken(buyer, id, amountToPay, amountToBuy, bonus);
    }    

    // allow ICO owner to close ICO and get back unsold tokens
    function closeICO(uint256 id) external {
        ICOParams storage p = icoParams[id];
        ICOState storage s = icoState[id];
        require(s.ICOOwner == msg.sender, "Only ICO owner");
        require(!s.isClosed, "Already closed");
        s.isClosed = true;
        uint256 value = p.amount - s.totalSold + p.bonusReserve;    // refund leftover tokens
        p.amount = s.totalSold;
        p.bonusReserve = 0;
        safeTransfer(p.token, msg.sender, value);
        emit CloseICO(id, msg.sender, p.token, value);
    }

    // Launchpad owner's functions
    function setPauseLaunchpad(bool pause) external onlyOwner {
        isPaused = pause;
    }

    function setVestingImplementation(address vestingImplementation_) external onlyOwner {
        vestingImplementation = vestingImplementation_;
    }

    event Rescue(address _token, uint256 _amount);
    function rescueTokens(address _token) onlyOwner external {
        uint256 amount;
        if (_token == address(0)) {
            amount = address(this).balance;
            safeTransferETH(msg.sender, amount);
        } else {
            amount = IERC20(_token).balanceOf(address(this));
            safeTransfer(_token, msg.sender, amount);
        }
        emit Rescue(_token, amount);
    }

    /**
     * @dev A clone instance deployment failed.
     */
    error ERC1167FailedCreateClone();

    /**
     * @dev Deploys and returns the address of a clone that mimics the behaviour of `implementation`.
     *
     * This function uses the create opcode, which should never revert.
     */
    function clone(address implementation) internal returns (address instance) {
        /// @solidity memory-safe-assembly
        assembly {
            // Cleans the upper 96 bits of the `implementation` word, then packs the first 3 bytes
            // of the `implementation` address with the bytecode before the address.
            mstore(0x00, or(shr(0xe8, shl(0x60, implementation)), 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000))
            // Packs the remaining 17 bytes of `implementation` with the bytecode after the address.
            mstore(0x20, or(shl(0x78, implementation), 0x5af43d82803e903d91602b57fd5bf3))
            instance := create(0, 0x09, 0x37)
        }
        if (instance == address(0)) {
            revert ERC1167FailedCreateClone();
        }
    }

    // allow to receive ERC223 tokens
    function tokenReceived(address, uint256, bytes memory) external virtual returns(bytes4) {
        return this.tokenReceived.selector;
    }

    function safeApprove(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('approve(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x095ea7b3, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: APPROVE_FAILED');
    }
    
    function safeTransfer(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FAILED');
    }

    function safeTransferFrom(address token, address from, address to, uint value) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FROM_FAILED');
    }

    function safeTransferETH(address to, uint value) internal {
        (bool success,) = to.call{value:value}(new bytes(0));
        require(success, 'TransferHelper: ETH_TRANSFER_FAILED');
    }
}
