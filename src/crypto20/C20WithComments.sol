pragma solidity 0.4.11;

import './Math.sol';
import './Token.sol';

/**
     *
     *
     * @param
     */

// CO1N5 Token
contract StandardToken is Token, Math {

    /*+-+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+-*
     * Standard members and ERC-20 Impl
     *+-+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+-*/
    string public name = "CO1N5";
    string public symbol = "CNS";
    uint256 public decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) balances;
    mapping(address => mapping(address => uint256)) allowed;

    function balanceOf(address _owner) constant returns (uint256 balance) {
        return balances[_owner];
    }

    // todo: check why onlyPayloadSize
    // prevent transfers until trading allowed
    function transfer(address _to, uint256 _value) onlyPayloadSize(2) isTradeable returns (bool success) {
        require(_value > 0);
        require(_to != address(0) && balances[msg.sender] >= _value);

        balances[msg.sender] = safeSub(balances[msg.sender], _value);
        balances[_to] = safeAdd(balances[_to], _value);
        Transfer(msg.sender, _to, _value);
        return true;
    }

    // prevent transfers until trading allowed
    function transferFrom(address _from, address _to, uint256 _value) onlyPayloadSize(3) isTradeable returns (bool success) {
        require(_value > 0);
        require(_to != address(0) && balances[_from] >= _value && allowed[_from][msg.sender] >= _value);

        balances[_from] = safeSub(balances[_from], _value);
        allowed[_from][msg.sender] = safeSub(allowed[_from][msg.sender], _value);
        balances[_to] = safeAdd(balances[_to], _value);
        Transfer(_from, _to, _value);
        return true;
    }

    // To change the approve amount you first have to reduce the addresses'
    //  allowance to zero by calling 'approve(_spender, 0)' if it is not
    //  already 0 to mitigate the race condition described here:
    //  https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
    function approve(address _spender, uint256 _value) onlyPayloadSize(2) returns (bool success) {
        require(_value == 0 || allowed[msg.sender][_spender] == 0);
        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) constant returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }


    function changeApproval(address _spender, uint256 _oldValue, uint256 _newValue) onlyPayloadSize(3) returns (bool success) {
        require(allowed[msg.sender][_spender] == _oldValue);
        allowed[msg.sender][_spender] = _newValue;
        Approval(msg.sender, _spender, _newValue);
        return true;
    }


    /*+-+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+-*
     * Extended Impl
     *+-+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+-*/

    // @Andreas: 86206896 * 10^18 wei
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
    mapping(address => bool) public whitelist;

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
    event Whitelist(address indexed participant);
    event PriceUpdate(uint256 numerator, uint256 denominator);
    event AddLiquidity(uint256 ethAmount);
    event RemoveLiquidity(uint256 ethAmount);
    event WithdrawRequest(address indexed participant, uint256 amountTokens);
    event Withdraw(address indexed participant, uint256 amountTokens, uint256 etherAmount);


    // MODIFIERS: Conditions for execution of functions

    modifier isTradeable {// exempt vestingContract and fundWallet to allow dev allocations
        require(tradeable || msg.sender == fundWallet || msg.sender == vestingContract);
        _;
    }
    modifier onlyWhitelist {
        require(whitelist[msg.sender]);
        _;
    }
    modifier onlyFundWallet {
        require(msg.sender == fundWallet);
        _;
    }
    modifier onlyManagingWallets {
        require(msg.sender == controlWallet || msg.sender == fundWallet);
        _;
    }
    modifier requireWaited {
        require(safeSub(now, waitTime) >= previousUpdateTime);
        _;
    }
    modifier requireVestingSet (uint256 newNumerator) {
        require(vestingSet);
        _;
    }

    // Info Andreas: No exception is thrown -> no gas but also no rollback. Money is gone!
    modifier requireIncreased (uint256 newNumerator) {
        if (newNumerator > currentPrice.numerator) _;
    }
    modifier onlyControlWallet {
        if (msg.sender == controlWallet) _;
    }


    // CONSTRUCTOR

    function C20(address controlWalletInput, uint256 priceNumeratorInput, uint256 startBlockInput, uint256 endBlockInput) {
        // Info: address(0) is the same as "0x0" -> an uninitialized address.
        require(controlWalletInput != address(0));
        require(priceNumeratorInput > 0);
        require(endBlockInput > startBlockInput);
        fundWallet = msg.sender;
        controlWallet = controlWalletInput;
        whitelist[fundWallet] = true;
        whitelist[controlWallet] = true;
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
        whitelist[vestingContract] = true;
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
        whitelist[participant] = true;
        // automatically whitelist accepted presale
        allocateTokens(participant, amountTokens);
        Whitelist(participant);
        AllocatePresale(participant, amountTokens);
    }

    // raise balance of participants and vestingContract and totalSupply
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


    function verifyParticipant(address participant) external onlyManagingWallets {
        whitelist[participant] = true;
        Whitelist(participant);
    }

    function buy() external payable {
        buyTo(msg.sender);
    }

    function buyTo(address participant) public payable onlyWhitelist {
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

    function requestWithdrawal(uint256 amountTokensToWithdraw) external isTradeable onlyWhitelist {
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