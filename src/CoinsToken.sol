pragma solidity 0.4.11;

import './Math.sol';
import './Safe.sol';
import './Token.sol';

// CO1N5 Token
contract CoinsToken is Token, Math, Safe {

    /*+-+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+-*
     * MODIFIERS: Conditions for execution of functions
     *            and throw an exception if the condition
     *            is not met.
     *+-+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+-*/

    /**
     * Check if trading is enabled. This condition does not apply to fundWallet and vestingContract.
     * @throws Exception if the condition is not met
     */
    modifier requireTradeable {
        require(tradeable || msg.sender == fundWallet || msg.sender == vestingContract);
        _;
    }

    /**
     * Check if msg.sender is a known participant of the ICO.
     * @throws Exception if the condition is not met
     */
    modifier requireIcoParticipant {
        require(icoParticipants[msg.sender]);
        _;
    }

    /**
     * Check if msg.sender is fundWallet.
     * @throws Exception if the condition is not met
     */
    modifier requireFundWallet {
        require(msg.sender == fundWallet);
        _;
    }

    /**
     * Check if msg.sender is fundWallet or controlWallet.
     * @throws Exception if the condition is not met
     */
    modifier requireManagingWallets {
        require(msg.sender == controlWallet || msg.sender == fundWallet);
        _;
    }

    /**
     * Check if msg.sender is controlWallet.
     * @throws Exception if the condition is not met
     */
    modifier onlyIfControlWallet {
        if(msg.sender == controlWallet) _;
    }

    /**
     * Check if waitTime has expired for the next price change.
     * @throws Exception if the condition is not met
     */
    modifier requireWaited {
        require(safeSub(now, waitTime) >= currentPriceStartTime);
        _;
    }

    /**
     * Check if a vesting contract is set
     * @throws Exception if the condition is not met
     */
    modifier requireVestingSet {
        require(vestingSet);
        _;
    }

    /**
     * Check if the ico period is finished
     * @throws Exception if the condition is not met
     */
    modifier requireIcoFinished {
        require(block.number >= icoEndBlock);
        _;
    }

    /**
     * Check if the ico period is active
     * @throws Exception if the condition is not met
     */
    modifier requireIcoNotExpired {
        require(block.number < icoEndBlock);
        _;
    }

    /**
     * Check if the ico period is active
     * @throws Exception if the condition is not met
     */
    modifier requireIcoActive {
        require(block.number >= icoStartBlock && block.number < icoEndBlock);
        _;
    }

    /**
     * Check if the passed address is valid.
     * @param addressToCheck - the address to be checked
     * @throws Exception if the condition is not met
     */
    modifier requireValidAddress(address addressToCheck) {
        require(addressToCheck != address(0));
        _;
    }

    /*+-+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+-*
     * Standard members and ERC-20 Impl
     *+-+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+-*/

    string public name = "CO1N5";
    string public symbol = "CNS";
    uint256 public decimals = 18;

    mapping(address => uint256) balances;
    mapping(address => mapping(address => uint256)) allowed;

    /**
     * Returns the balance of the passed address
     *
     * @param holder - the address to check
     * @return balance of the passed address
     */
    function balanceOf(address holder) constant returns (uint256 balance) {
        return balances[holder];
    }

    // todo: check onlyPayloadSize 2 oder 3?
    /**
     * Transfers tokens to an other address.
     *
     * @event Transfer
     * @modifier onlyPayloadSize - prevent short address attack
     * @modifier requireTradeable - prevent transfers until trading allowed
     * @modifier requireValidAddress - prevent transfers to invalid receiver addresses
     * @param receiver - the receiver address
     * @param value - amount of tokens to transfer
     * @return true if the transfer was successful
     */
    function transfer(address receiver, uint256 value) onlyPayloadSize(2) requireTradeable requireValidAddress(receiver) returns (bool success) {
        require(value > 0 && balances[msg.sender] >= value);

        balances[msg.sender] = safeSub(balances[msg.sender], value);
        balances[receiver] = safeAdd(balances[receiver], value);
        Transfer(msg.sender, receiver, value);
        return true;
    }

    //check onlyPayloadSize 2 oder 3?
    /**
     * Transfers tokens from spender to receiver address if msg.sender is allowed to.
     *
     * @event Transfer
     * @modifier onlyPayloadSize - prevent short address attack
     * @modifier requireTradeable - prevent transfers until trading allowed
     * @modifier requireValidAddress - prevent transfers to invalid receiver addresses
     * @param spender - the spender address
     * @param receiver - the receiver address
     * @param value - amount of tokens to transfer
     * @return true if the transfer was successful
     */
    function transferFrom(address spender, address receiver, uint256 value) onlyPayloadSize(3) requireTradeable requireValidAddress(receiver) returns (bool success) {
        require(value > 0 && balances[spender] >= value && allowed[spender][msg.sender] >= value);

        balances[spender] = safeSub(balances[spender], value);
        allowed[spender][msg.sender] = safeSub(allowed[spender][msg.sender], value);
        balances[receiver] = safeAdd(balances[receiver], value);
        Transfer(spender, receiver, value);
        return true;
    }

    /**
     * Authorizes a spender for the passed amount of tokens. To change the approved amount
     * first the addresses' approval has to be set to zero by calling 'approve(_spender, 0)'
     *
     * @event Approval
     * @modifier onlyPayloadSize - prevent short address attack
     * @modifier requireTradeable - prevent transfers until trading allowed
     * @param spender - the spender address
     * @param receiver - the receiver address
     * @param value - amount of tokens to authorize
     * @return true if the authorization was successful
     */
    function approve(address spender, uint256 value) onlyPayloadSize(2) returns (bool success) {
        require(value == 0 || allowed[msg.sender][spender] == 0);

        allowed[msg.sender][spender] = value;
        Approval(msg.sender, spender, value);
        return true;
    }

    /**
     * Returns the authorized amount of tokens for a spender.
     *
     * @param holder - the token owner
     * @param spender - the authorized address
     * @return the amount of authorized tokens
     */
    function getApproval(address holder, address spender) constant returns (uint256 remaining) {
        return allowed[holder][spender];
    }

    /**
     * Changes the amount of authorized tokens for a spender.
     *
     * @param holder - the token owner
     * @param spender - the authorized address
     * @return the amount of authorized tokens
     */
    function changeApproval(address spender, uint256 oldValue, uint256 newValue) onlyPayloadSize(3) returns (bool success) {
        require(allowed[msg.sender][spender] == oldValue);
        allowed[msg.sender][spender] = newValue;
        Approval(msg.sender, spender, newValue);
        return true;
    }


    /*+-+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+-*
     *
     * CO1N5 CONTRACT:
     *     - token capitalization: 86206896 * (10 ** 18)
     *     - minimum amount of ether to buy Co1n5 Tokens: 0.04 ether
     *     - development: XX% of Pre-sale and ICO
     *     -
     *
     *+-+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+-*/

    // 86206896 * 10^18 wei
    uint256 public tokenCap = 86206896 * (10 ** 18);

    // supplied tokens
    uint256 public totalSupply;

    // price parameter.
    Price public currentPrice;
    // time to wait between price updates
    uint256 public waitTime = 5 hours;
    uint256 public currentPriceStartTime = 0;
    mapping(uint256 => Price) public prices;

    // ico parameters
    uint256 public icoStartBlock;
    uint256 public icoEndBlock;
    uint256 public minAmount = 0.04 ether;
    mapping(address => bool) public icoParticipants;


    // vesting fields
    address public vestingContract;
    bool private vestingSet = false;

    // root control wallets
    address public fundWallet;
    address public controlWallet;

    // halted: halt buying due to emergency
    bool public halted = false;
    // tradeable: signal that assets have been acquired
    bool public tradeable = false;

    // map participant address to a withdrawal request
    mapping(address => Withdrawal) public withdrawals;


    // Price: tokens per eth
    struct Price {
        uint256 numerator;
        uint256 denominator;
    }

    // Withdrawal: amount and time for exchange rate
    struct Withdrawal {
        uint256 tokens;
        uint256 time;
    }


    // EVENTS
    event Buy(address indexed participant, address indexed beneficiary, uint256 ethValue, uint256 amountTokens);
    event AllocatePresale(address indexed participant, uint256 amountTokens);
    event IcoParticipant(address indexed participant);
    event PriceUpdate(uint256 numerator, uint256 denominator);
    event AddLiquidity(uint256 ethAmount);
    event RemoveLiquidity(uint256 ethAmount);
    event WithdrawRequest(address indexed participant, uint256 amountTokens);
    event Withdraw(address indexed participant, uint256 amountTokens, uint256 etherAmount);


    /**
     * Constructs the contract.
     *
     * @param controlWalletIn - the controlWallet
     * @param priceNumerator - numerator for price calculation
     * @param priceDenominator - denominator for price calculation
     * @param startBlockIn - planned start block of ICO
     * @param endBlockIn - planned end block of ICO
     */
    function CoinsToken(address controlWalletIn, uint256 priceNumerator, uint256 priceDenominator, uint256 startBlockIn, uint256 endBlockIn) {
        require(controlWalletIn != address(0));
        require(priceNumeratorIn > 0);
        require(endBlockIn > startBlockIn);

        fundWallet = msg.sender;
        controlWallet = controlWalletIn;
        icoParticipants[fundWallet] = true;
        icoParticipants[controlWallet] = true;

        icoStartBlock = startBlockIn;
        icoEndBlock = endBlockIn;

        currentPrice = Price(priceNumerator, priceDenominator);
        currentPriceStartTime = now;
    }

    /**
     * Updates the vestingContract.
     *
     * @modifier requireFundWallet - only fundWallet can change the vestingContract
     * @modifier requireValidAddress - prevent setting an invalid vestingContract
     * @param in - the new vestingContract
     */
    function updateVestingContract(address in) external requireFundWallet requireValidAddress(in) {
        vestingContract = in;
        icoParticipants[vestingContract] = true;
        vestingSet = true;
    }

    /**
     * Updates the vestingContract.
     *
     * @modifier requireFundWallet - only fundWallet can change the fundWallet
     * @modifier requireValidAddress - prevent setting an invalid fundWallet
     * @param in - the new fundWallet
     */
    function updateFundWallet(address in) external requireFundWallet requireValidAddress(in) {
        fundWallet = in;
        icoParticipants[fundWallet] = true; //check
    }

    /**
     * Updates the controlWallet.
     *
     * @modifier requireFundWallet - only fundWallet can change the controlWallet
     * @modifier requireValidAddress - prevent setting an invalid controlWallet
     * @param in - the new controlWallet
     */
    function updateControlWallet(address in) external requireFundWallet requireValidAddress(in) {
        controlWallet = in;
        icoParticipants[controlWallet] = true; //check
    }

    /**
     * Updates the waitTime.
     *
     * @modifier requireFundWallet - only fundWallet can change the controlWallet
     * @param in - the waitTime in hours
     */
    function updateWaitTime(uint256 newWaitTime) external requireFundWallet {
        require(newWaitTime >= 0); //check
        waitTime = newWaitTime * 1 hours; //check
    }

    /**
     * Updates block number of ICO start.
     *
     * @modifier requireFundWallet - only fundWallet can change the start time
     * @param newIcoStartBlock - the new block number for ICO start
     */
    function updateIcoStartBlock(uint256 newIcoStartBlock) external requireFundWallet {
        require(block.number < icoStartBlock); //check if needed
        require(block.number < newIcoStartBlock);
        icoStartBlock = newIcoStartBlock;
    }

    /**
     * Updates block number of ICO end.
     *
     * @modifier requireFundWallet - only fundWallet can change the start time
     * @modifier requireIcoNotExpired - ico must not be expired
     * @param newIcoEndBlock - the new block number for ICO end
     */
    function updateIcoEndBlock(uint256 newIcoEndBlock) external requireFundWallet requireIcoNotExpired {
        require(block.number < newIcoEndBlock);
        icoEndBlock = newIcoEndBlock;
    }

    /**
     * Updates the numerator for price calculation. Only controlWallet calls are compliant and limited
     * to 20% increase within a fixed period.
     *
     * @event PriceUpdate
     * @modifier requireManagingWallets - only fundWallet or controlWallet can change the start time
     * @param newNumerator - the new numerator for price calculation
     */
    function updatePrice(uint256 newNumerator) external requireManagingWallets {
        require(newNumerator > 0);
        requireLimitedChange(newNumerator);
        // either controlWallet command is compliant or transaction came from fundWallet
        currentPrice.numerator = newNumerator;
        // maps time to new Price (if not during ICO)
        prices[currentPriceStartTime] = currentPrice;
        currentPriceStartTime = now;
        PriceUpdate(newNumerator, currentPrice.denominator);
    }

    /**
     * Updates the numerator for price calculation. Only controlWallet calls are compliant and are limited
     * to 20% increase within a fixed period.
     *
     * @modifier onlyIfControlWallet - only if controlWallet, if not return to caller
     * @modifier requireWaited - only if waiting period is over, otherwise skip transaction
     * @param newNumerator - the new numerator for price calculation
     */
    function requireLimitedChange(uint256 newNumerator) private onlyIfControlWallet requireWaited {
        if (newNumerator > currentPrice.numerator) {
            uint256 percentage_diff = 0;
            percentage_diff = safeMul(newNumerator, 100) / currentPrice.numerator;
            percentage_diff = safeSub(percentage_diff, 100);
            require(percentage_diff <= 20);
        }
    }

    /**
     * Updates the denominator for price calculation. The update has no limit and no wait time
     * and is not allowed during the ICO period.
     *
     * @event PriceUpdate
     * @modifier requireFundWallet - only fundWallet can change the denominator
     * @modifier requireIcoFinished - no change during ICO
     * @param newDenominator - the new denominator for price calculation
     */
    function updatePriceDenominator(uint256 newDenominator) external requireFundWallet requireIcoFinished {
        require(newDenominator > 0);
        currentPrice.denominator = newDenominator;
        // maps time to new Price
        prices[currentPriceStartTime] = currentPrice;
        currentPriceStartTime = now;
        PriceUpdate(currentPrice.numerator, newDenominator);
    }


    /**
     * Adds a participant to the ICO white-list.
     *
     * @event IcoParticipant
     * @modifier requireManagingWallets - only fundWallet or controlWallet can register participants
     * @param participant - participant for ICO
     */
    function registerIcoParticipant(address participant) external requireManagingWallets {
        icoParticipants[participant] = true;
        IcoParticipant(participant);
    }

    /**
     * PRE-SALE PHASE: Allocates tokens during the pre-sale period.
     *
     * @event IcoParticipant
     * @event AllocatePresale
     * @modifier requireFundWallet - only fundWallet can change the denominator
     * @modifier requireValidAddress - participant address must be valid
     * @modifier requireIcoNotExpired - ico must not be expired
     * @param participant - new participant for ICO
     * @param value - amount of pre-sale tokens
     */
    function allocatePresaleTokens(address participant, uint value) external requireFundWallet requireValidAddress(participant) requireIcoNotExpired {
        icoParticipants[participant] = true;
        allocateTokens(participant, value);

        IcoParticipant(participant);
        AllocatePresale(participant, value);
    }

    /**
     * Allocates tokens for the passed participant and allocates the corresponding development tokens.
     *
     * @modifier requireVestingSet - a vestingContract must be set
     * @param participant - participant for ICO
     * @param value - amount of tokens
     */
    function allocateTokens(address participant, uint256 value) private requireVestingSet { //check: requireIcoParticipant
        uint256 developmentAllocation = safeMul(value, 14942528735632185) / 100000000000000000;

        // check that token cap is not exceeded
        uint256 newTokens = safeAdd(value, developmentAllocation);
        uint256 newTokenCap = safeAdd(totalSupply, newTokens);
        require(newTokenCap <= tokenCap);

        // increase token supply, assign tokens to participant
        totalSupply = safeAdd(totalSupply, newTokens);
        balances[participant] = safeAdd(balances[participant], value);
        balances[vestingContract] = safeAdd(balances[vestingContract], developmentAllocation);
    }

    /**
     * ICO PHASE: Allocates tokens during the pre-sale period.
     *
     * @event IcoParticipant
     * @event AllocatePresale
     * @modifier requireFundWallet - only fundWallet can change the denominator
     * @modifier requireValidAddress - participant address must be valid
     * @modifier requireIcoNotExpired - ico must not be expired
     * @param participant - new participant for ICO
     * @param value - amount of pre-sale tokens
     */
    function buy() external payable {
        buyTo(msg.sender);
    }

//* @modifier requireIcoActive - ico must not be expired
    function buyTo(address participant) public payable requireIcoParticipant requireIcoActive {
        require(!halted);
        require(participant != address(0));
        require(msg.value >= minAmount);
        uint256 icoDenominator = icoDenominatorPrice();
        uint256 tokensToBuy = safeMul(msg.value, currentPrice.numerator) / icoDenominator;
        allocateTokens(participant, tokensToBuy);
        // send ether to fundWallet
        fundWallet.transfer(msg.value);
        Buy(msg.sender, participant, msg.value, tokensToBuy);
    }

    // time based on blocknumbers, assuming a blocktime of 30s
    function icoDenominatorPrice() public constant returns (uint256) {
        uint256 icoDuration = safeSub(block.number, icoStartBlock);
        uint256 denominator;
        if (icoDuration < 2880) {// #blocks = 24*60*60/30 = 2880
            return currentPrice.denominator;
        } else if (icoDuration < 80640) {// #blocks = 4*7*24*60*60/30 = 80640
            denominator = safeMul(currentPrice.denominator, 105) / 100;
            return denominator;
        } else {
            denominator = safeMul(currentPrice.denominator, 110) / 100;
            return denominator;
        }
    }

    function requestWithdrawal(uint256 amountTokensToWithdraw) external requireTradeable requireIcoParticipant requireIcoFinished {
        require(amountTokensToWithdraw > 0);
        address participant = msg.sender;
        require(balances[participant] >= amountTokensToWithdraw);
        require(withdrawals[participant].tokens == 0);
        // participant cannot have outstanding withdrawals
        balances[participant] = safeSub(balances[participant], amountTokensToWithdraw);
        withdrawals[participant] = Withdrawal({tokens : amountTokensToWithdraw, time : currentPriceStartTime});
        WithdrawRequest(participant, amountTokensToWithdraw);
    }

    function withdraw() external {
        address participant = msg.sender;
        uint256 tokens = withdrawals[participant].tokens;
        require(tokens > 0);
        // participant must have requested a withdrawal
        uint256 requestTime = withdrawals[participant].time;
        // obtain the next price that was set after the request
        Price price = prices[requestTime];
        require(price.numerator > 0);
        // price must have been set
        uint256 withdrawValue = safeMul(tokens, price.denominator) / price.numerator;
        // if contract ethbal > then send + transfer tokens to fundWallet, otherwise give tokens back
        withdrawals[participant].tokens = 0;
        if (this.balance >= withdrawValue)
            enact_withdrawal_greater_equal(participant, withdrawValue, tokens);
        else
            enact_withdrawal_less(participant, withdrawValue, tokens);
    }

    function enact_withdrawal_greater_equal(address participant, uint256 withdrawValue, uint256 tokens)
    private
    {
        assert(this.balance >= withdrawValue);
        balances[fundWallet] = safeAdd(balances[fundWallet], tokens);
        participant.transfer(withdrawValue);
        Withdraw(participant, tokens, withdrawValue);
    }

    function enact_withdrawal_less(address participant, uint256 withdrawValue, uint256 tokens)
    private
    {
        assert(this.balance < withdrawValue);
        balances[participant] = safeAdd(balances[participant], tokens);
        Withdraw(participant, tokens, 0);
        // indicate a failed withdrawal
    }


    function checkWithdrawValue(uint256 amountTokensToWithdraw) constant returns (uint256 etherValue) {
        require(amountTokensToWithdraw > 0);
        require(balances[msg.sender] >= amountTokensToWithdraw);
        uint256 withdrawValue = safeMul(amountTokensToWithdraw, currentPrice.denominator) / currentPrice.numerator;
        require(this.balance >= withdrawValue);
        return withdrawValue;
    }

    // allow fundWallet or controlWallet to add ether to contract
    function addLiquidity() external requireManagingWallets payable {
        require(msg.value > 0);
        AddLiquidity(msg.value);
    }

    // allow fundWallet to remove ether from contract
    function removeLiquidity(uint256 amount) external requireManagingWallets {
        require(this.balance >= amount);
        fundWallet.transfer(amount);
        RemoveLiquidity(amount);
    }

    function halt() external requireFundWallet {
        halted = true;
    }

    function unhalt() external requireFundWallet {
        halted = false;
    }

    function enableTrading() external requireFundWallet requireIcoFinished {
        tradeable = true;
    }

    // fallback function
    function() payable {
        require(tx.origin == msg.sender);
        buyTo(msg.sender);
    }

    function claimTokens(address _token) external requireFundWallet {
        require(_token != address(0));
        Token token = Token(_token);
        uint256 balance = token.balanceOf(this);
        token.transfer(fundWallet, balance);
    }
}
