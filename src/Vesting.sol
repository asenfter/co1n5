
  pragma solidity 0.4.11;

  import './Token.sol';
  import './Math.sol';

  /**
   * to claim stored tokens after 6 month intervals
  */

   contract Vesting is Math {

      address public beneficiary;
      uint256 public fundingEndBlock;

      bool private initClaim = false; // state tracking variables

      uint256 public firstRelease; // vesting times
      bool private firstDone = false;
      uint256 public secondRelease;
      bool private secondDone = false;
      uint256 public thirdRelease;
      bool private thirdDone = false;
      uint256 public fourthRelease;

      Token public erc20Token; // ERC20 basic token contract to hold

      enum Stages {
          initClaim,
          firstRelease,
          secondRelease,
          thirdRelease,
          fourthRelease
      }

      Stages public stage = Stages.initClaim;

       // Info Andreas: do not throw! otherwise no claim would ever happen!
      modifier atStage(Stages _stage) {
          if(stage == _stage) _;
      }

      function Vesting(address _token, uint256 fundingEndBlockInput) {
          require(_token != address(0));
          beneficiary = msg.sender;
          fundingEndBlock = fundingEndBlockInput;
          erc20Token = Token(_token);
      }

      function changeBeneficiary(address newBeneficiary) external {
          require(newBeneficiary != address(0));
          require(msg.sender == beneficiary);
          beneficiary = newBeneficiary;
      }

      function updateFundingEndBlock(uint256 newFundingEndBlock) {
          require(msg.sender == beneficiary);
          require(block.number < fundingEndBlock);
          require(block.number < newFundingEndBlock);
          fundingEndBlock = newFundingEndBlock;
      }

      function checkBalance() constant returns (uint256 tokenBalance) {
          return erc20Token.balanceOf(this);
      }

      // in total 13% of C20 tokens will be sent to this contract
      // EXPENSE ALLOCATION: 5.5%       | TEAM ALLOCATION: 7.5% (vest over 2 years)
      //   2.5% - Marketing             | initalPayment: 1.5%
      //   1% - Security                | firstRelease: 1.5%
      //   1% - legal                   | secondRelease: 1.5%
      //   0.5% - Advisors              | thirdRelease: 1.5%
      //   0.5% - Boutnty               | fourthRelease: 1.5%
      // initial claim is tot expenses + initial team payment
      // initial claim is thus (5.5 + 1.5)/13 = 53.846153846% of C20 tokens sent here
      // each other release (for team) is 11.538461538% of tokens sent here

       // Info Andreas: Check whether this fn is safe or not. Race condition
      function claim() external {
          require(msg.sender == beneficiary);
          require(block.number > fundingEndBlock);
          uint256 balance = erc20Token.balanceOf(this);
          // in reverse order so stages changes don't carry within one claim
          fourth_release(balance); // all remaining tokens.
          third_release(balance); // 50% of the 23%: 11,5% of initial vesting tokens (11,5% remaining)
          second_release(balance); // 33% ot the 34,5%: 11,5% of initial vesting tokens (23% remaining)
          first_release(balance); //  25% of the 46%: 11,5% of initial vesting tokens (34,5% remaining)
          init_claim(balance); // initial payout 54% of all vesting tokens (46% remaining)
      }

      function nextStage() private {
          stage = Stages(uint256(stage) + 1);
      }

       // Info Andreas: The first claim can happen immediately after "require(block.number > fundingEndBlock)"
      function init_claim(uint256 balance) private atStage(Stages.initClaim) {
          firstRelease = now + 26 weeks; // assign 4 claiming times
          secondRelease = firstRelease + 26 weeks;
          thirdRelease = secondRelease + 26 weeks;
          fourthRelease = thirdRelease + 26 weeks;
          uint256 amountToTransfer = safeMul(balance, 53846153846) / 100000000000;
          erc20Token.transfer(beneficiary, amountToTransfer); // now 46.153846154% tokens left
          nextStage();
      }
      function first_release(uint256 balance) private atStage(Stages.firstRelease) {
          require(now > firstRelease);
          uint256 amountToTransfer = balance / 4;
          erc20Token.transfer(beneficiary, amountToTransfer); // send 25 % of team releases
          nextStage();
      }
      function second_release(uint256 balance) private atStage(Stages.secondRelease) {
          require(now > secondRelease);
          uint256 amountToTransfer = balance / 3;
          erc20Token.transfer(beneficiary, amountToTransfer); // send 25 % of team releases
          nextStage();
      }
      function third_release(uint256 balance) private atStage(Stages.thirdRelease) {
          require(now > thirdRelease);
          uint256 amountToTransfer = balance / 2;
          erc20Token.transfer(beneficiary, amountToTransfer); // send 25 % of team releases
          nextStage();
      }
      function fourth_release(uint256 balance) private atStage(Stages.fourthRelease) {
          require(now > fourthRelease);
          erc20Token.transfer(beneficiary, balance); // send remaining 25 % of team releases
      }

      // Info Andreas: is this best practice? does this work? require(token != erc20Token) or should the underlying address be compared?
      function claimOtherTokens(address _token) external {
          require(msg.sender == beneficiary);
          require(_token != address(0));
          Token token = Token(_token);
          require(token != erc20Token);
          uint256 balance = token.balanceOf(this);
          token.transfer(beneficiary, balance);
       }
   }
