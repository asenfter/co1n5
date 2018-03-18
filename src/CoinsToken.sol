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
    modifier isTradeable {
        require(tradeable || msg.sender == fundWallet || msg.sender == vestingContract);
        _;
    }

    /**
     * Check if msg.sender is a known participant of the ICO.
     * @throws Exception if the condition is not met
     */
    modifier onlyIcoParticipant {
        require(icoParticipants[msg.sender]);
        _;
    }

    /**
     * Check if msg.sender is fundWallet.
     * @throws Exception if the condition is not met
     */
    modifier onlyFundWallet {
        require(msg.sender == fundWallet);
        _;
    }

    /**
     * Check if msg.sender is fundWallet or controlWallet.
     * @throws Exception if the condition is not met
     */
    modifier onlyManagingWallets {
        require(msg.sender == controlWallet || msg.sender == fundWallet);
        _;
    }

    /**
     * Check if msg.sender is controlWallet.
     * @throws Exception if the condition is not met
     */
    modifier onlyControlWallet {
        require(msg.sender == controlWallet);
        _;
    }

    /**
     * Check if waitTime has expired for the next price change.
     * @throws Exception if the condition is not met
     */
    modifier requireWaited {
        require(safeSub(now, waitTime) >= previousUpdateTime);
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
     * Check if the passed address is valid.
     * @param addressToCheck - the address to be checked
     * @throws Exception if the condition is not met
     */
    modifier isValidAddress (address addressToCheck) {
        require(addressToCheck != address(0));
        _;
    }

    /**
     * Check if the passed value is greater than currentPrice.numerator.
     * No exception is thrown: no gas but also no rollback
     * @param value - new numerator
     */
    modifier requireIncreased (uint256 value) {
        if (value > currentPrice.numerator) _;
    }


    /*+-+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+-*
     * Standard members and ERC-20 Impl
     *+-+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+-*/

    string public name = "CO1N5";
    string public symbol = "CNS";
    uint256 public decimals = 18;
    uint256 public totalSupply;

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

    // todo Andreas: check onlyPayloadSize 2 oder 3?
    /**
     * Transfers tokens to an other address.
     *
     * @event Transfer
     * @modifier onlyPayloadSize - prevent short address attack
     * @modifier isTradeable - prevent transfers until trading allowed
     * @modifier isValidAddress - prevent transfers to invalid receiver addresses
     * @param receiver - the receiver address
     * @param value - amount of tokens to transfer
     * @return true if the transfer was successful
     */
    function transfer(address receiver, uint256 value) onlyPayloadSize(2) isTradeable isValidAddress(receiver) returns (bool success) {
        require(value > 0 && balances[msg.sender] >= value);

        balances[msg.sender] = safeSub(balances[msg.sender], value);
        balances[receiver] = safeAdd(balances[receiver], value);
        Transfer(msg.sender, receiver, value);
        return true;
    }

    // todo Andreas: check onlyPayloadSize 2 oder 3?
    /**
     * Transfers tokens from spender to receiver address if msg.sender is allowed to.
     *
     * @event Transfer
     * @modifier onlyPayloadSize - prevent short address attack
     * @modifier isTradeable - prevent transfers until trading allowed
     * @modifier isValidAddress - prevent transfers to invalid receiver addresses
     * @param spender - the spender address
     * @param receiver - the receiver address
     * @param value - amount of tokens to transfer
     * @return true if the transfer was successful
     */
    function transferFrom(address spender, address receiver, uint256 value) onlyPayloadSize(3) isTradeable isValidAddress(receiver) returns (bool success) {
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
     * @modifier isTradeable - prevent transfers until trading allowed
     * @modifier isValidAddress - prevent transfers to invalid receiver addresses
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
     *     - vesting: 14.9425% of Pre-sale and ICO
     *     -
     *
     *+-+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+-*/

    // 86206896 * 10^18 wei
    uint256 public tokenCap = 86206896 * (10 ** 18);

    // crowdsale parameters
    uint256 public fundingStartBlock;
    uint256 public fundingEndBlock;

    // vesting fields
    address public vestingContract;
    bool private vestingSet = false;

    // root control
    address public fundWallet;
    // control of liquidity and limited control of updatePrice
    address public controlWallet;
    // time to wait between controlWallet price updates
    uint256 public waitTime = 5 hours;

    // fundWallet controlled state variables
    // halted: halt buying due to emergency, tradeable: signal that assets have been acquired
    bool public halted = false;
    bool public tradeable = false;


    uint256 public previousUpdateTime = 0;
    Price public currentPrice;
    uint256 public minAmount = 0.04 ether;

    // map participant address to a withdrawal request
    mapping(address => Withdrawal) public withdrawals;
    // maps previousUpdateTime to the next price
    mapping(uint256 => Price) public prices;
    // maps addresses
    mapping(address => bool) public icoParticipants;

    // TYPES
    struct Price {// tokensPerEth
        uint256 numerator;
        uint256 denominator;
    }

    struct Withdrawal {
        uint256 tokens;
        uint256 time; // time for each withdrawal is set to the previousUpdateTime
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


    // CONSTRUCTOR

    function C20(address controlWalletInput, uint256 priceNumeratorInput, uint256 startBlockInput, uint256 endBlockInput) {
        // Info: address(0) is the same as "0x0" -> an uninitialized address.
        require(controlWalletInput != address(0));
        require(priceNumeratorInput > 0);
        require(endBlockInput > startBlockInput);
        fundWallet = msg.sender;
        controlWallet = controlWalletInput;
        icoParticipants[fundWallet] = true;
        icoParticipants[controlWallet] = true;
        currentPrice = Price(priceNumeratorInput, 1000);
        // 1 token = 1 usd at ICO start
        fundingStartBlock = startBlockInput;
        fundingEndBlock = endBlockInput;
        previousUpdateTime = now;
    }

    // METHODS

    // Only the fixed FundWallet can set or update the vestingContract
    function setVestingContract(address vestingContractInput) external onlyFundWallet {
        // Info: address(0) is the same as "0x0" -> an uninitialized address.
        require(vestingContractInput != address(0));
        vestingContract = vestingContractInput;
        icoParticipants[vestingContract] = true;
        vestingSet = true;
    }

    // UPDATE Price.numerator
    // allows controlWallet or fundWallet to update the price within a time constraint,
    // allows fundWallet complete control over Price: fundwallet has no 20% limitation and can also decrease numerator!!!!
    // requires: newNumerator > currentNumerator
    // waitTime must be exceeded since last update
    function updatePrice(uint256 newNumerator) external onlyManagingWallets {
        require(newNumerator > 0);
        requireLimitedChange(newNumerator);
        // either controlWallet command is compliant or transaction came from fundWallet
        currentPrice.numerator = newNumerator;
        // maps time to new Price (if not during ICO)
        prices[previousUpdateTime] = currentPrice;
        previousUpdateTime = now;
        PriceUpdate(newNumerator, currentPrice.denominator);
    }

    // controlWallet can only increase price by max 20% and only every waitTime
    function requireLimitedChange(uint256 newNumerator) private onlyControlWallet requireWaited requireIncreased(newNumerator) {
        uint256 percentage_diff = 0;
        percentage_diff = safeMul(newNumerator, 100) / currentPrice.numerator;
        percentage_diff = safeSub(percentage_diff, 100);
        require(percentage_diff <= 20);
    }

    // UPDATE Price.numerator
    // allows fundWallet to update the denominator within a time contstraint
    function updatePriceDenominator(uint256 newDenominator) external onlyFundWallet {
        require(block.number > fundingEndBlock);
        require(newDenominator > 0);
        currentPrice.denominator = newDenominator;
        // maps time to new Price
        prices[previousUpdateTime] = currentPrice;
        previousUpdateTime = now;
        PriceUpdate(currentPrice.numerator, newDenominator);
    }


    function allocatePresaleTokens(address participant, uint amountTokens) external onlyFundWallet {
        require(block.number < fundingEndBlock);
        require(participant != address(0));
        icoParticipants[participant] = true;
        // automatically icoParticipants accepted presale
        allocateTokens(participant, amountTokens);
        IcoParticipant(participant);
        AllocatePresale(participant, amountTokens);
    }

    // raise balance of icoParticipants and vestingContract and totalSupply
    // vestingContract is increased by 14,9% of amountTokens
    function allocateTokens(address participant, uint256 amountTokens) private requireVestingSet {
        // 13% of total allocated for PR, Marketing, Team, Advisors
        uint256 developmentAllocation = safeMul(amountTokens, 14942528735632185) / 100000000000000000;
        // check that token cap is not exceeded
        uint256 newTokens = safeAdd(amountTokens, developmentAllocation);
        require(safeAdd(totalSupply, newTokens) <= tokenCap);
        // increase token supply, assign tokens to participant
        totalSupply = safeAdd(totalSupply, newTokens);
        balances[participant] = safeAdd(balances[participant], amountTokens);
        balances[vestingContract] = safeAdd(balances[vestingContract], developmentAllocation);
    }


    function addIcoParticipant(address participant) external onlyManagingWallets {
        icoParticipants[participant] = true;
        IcoParticipant(participant);
    }

    function buy() external payable {
        buyTo(msg.sender);
    }

    function buyTo(address participant) public payable onlyIcoParticipant {
        require(!halted);
        require(participant != address(0));
        require(msg.value >= minAmount);
        require(block.number >= fundingStartBlock && block.number < fundingEndBlock);
        uint256 icoDenominator = icoDenominatorPrice();
        uint256 tokensToBuy = safeMul(msg.value, currentPrice.numerator) / icoDenominator;
        allocateTokens(participant, tokensToBuy);
        // send ether to fundWallet
        fundWallet.transfer(msg.value);
        Buy(msg.sender, participant, msg.value, tokensToBuy);
    }

    // time based on blocknumbers, assuming a blocktime of 30s
    function icoDenominatorPrice() public constant returns (uint256) {
        uint256 icoDuration = safeSub(block.number, fundingStartBlock);
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

    function requestWithdrawal(uint256 amountTokensToWithdraw) external isTradeable onlyIcoParticipant {
        require(block.number > fundingEndBlock);
        require(amountTokensToWithdraw > 0);
        address participant = msg.sender;
        require(balances[participant] >= amountTokensToWithdraw);
        require(withdrawals[participant].tokens == 0);
        // participant cannot have outstanding withdrawals
        balances[participant] = safeSub(balances[participant], amountTokensToWithdraw);
        withdrawals[participant] = Withdrawal({tokens : amountTokensToWithdraw, time : previousUpdateTime});
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
    function addLiquidity() external onlyManagingWallets payable {
        require(msg.value > 0);
        AddLiquidity(msg.value);
    }

    // allow fundWallet to remove ether from contract
    function removeLiquidity(uint256 amount) external onlyManagingWallets {
        require(this.balance >= amount);
        fundWallet.transfer(amount);
        RemoveLiquidity(amount);
    }

    function changeFundWallet(address newFundWallet) external onlyFundWallet {
        require(newFundWallet != address(0));
        fundWallet = newFundWallet;
    }

    function changeControlWallet(address newControlWallet) external onlyFundWallet {
        require(newControlWallet != address(0));
        controlWallet = newControlWallet;
    }

    function changeWaitTime(uint256 newWaitTime) external onlyFundWallet {
        waitTime = newWaitTime;
    }

    function updateFundingStartBlock(uint256 newFundingStartBlock) external onlyFundWallet {
        require(block.number < fundingStartBlock);
        require(block.number < newFundingStartBlock);
        fundingStartBlock = newFundingStartBlock;
    }

    function updateFundingEndBlock(uint256 newFundingEndBlock) external onlyFundWallet {
        require(block.number < fundingEndBlock);
        require(block.number < newFundingEndBlock);
        fundingEndBlock = newFundingEndBlock;
    }

    function halt() external onlyFundWallet {
        halted = true;
    }

    function unhalt() external onlyFundWallet {
        halted = false;
    }

    function enableTrading() external onlyFundWallet {
        require(block.number > fundingEndBlock);
        tradeable = true;
    }

    // fallback function
    function() payable {
        require(tx.origin == msg.sender);
        buyTo(msg.sender);
    }

    function claimTokens(address _token) external onlyFundWallet {
        require(_token != address(0));
        Token token = Token(_token);
        uint256 balance = token.balanceOf(this);
        token.transfer(fundWallet, balance);
    }
}
