# Create a contract on the test net

1. download Misc from [https://github.com/ethereum/mist/releases]
2. Install Misc and start the application. Quit sync by clicking "Launch Application"
3. Connect to Test-Net via Menü->Entwicklung->Netzwerk->Rinkeby Test-Netzwerk
4. Click on search button on the left (Browser within the Misc app) and open [https://faucet.rinkeby.io/]
5. get some ether via twitter: see https://www.youtube.com/watch?v=DEULs3ShTxo
6. Now you have ether and can create contracts on the test net.
7. open IDE using Menü->Entwicklung->Remix IDE öffnen


# Solidity

###Best practice
https://github.com/ConsenSys/smart-contract-best-practices/#circuit-breakers-pause-contract-functionality


###GAS
https://ethereum.stackexchange.com/questions/18778/gas-cost-of-different-computations


### functions
http://solidity.readthedocs.io/en/develop/contracts.html?highlight=pure#functions

constant is an alias to view.


public vs external
https://ethereum.stackexchange.com/questions/19380/external-vs-public-best-practices?answertab=active#tab-top



modifier or require
https://ethereum.stackexchange.com/questions/29867/using-require-or-modifier


modifier as interceptor
https://blog.colony.io/how-to-write-clean-elegant-solidity-code-using-function-modifiers-ba55fb366a92
modifier ... {
 StartEvent(...)
 -;
 EndEvent(...)
}



throw exception in modifier (yes/no)
https://ethereum.stackexchange.com/questions/8436/why-use-throw-in-modifiers-instead-of-conditional-entrance
https://blog.colony.io/how-to-write-clean-elegant-solidity-code-using-function-modifiers-ba55fb366a92
modifier ... {
 if(...) throw
 _;
}
modifier ... {
 if(...) _;
}
modifier ... {
 require()
 _;
}





### variables
Info: address(0) is the same as "0x0", an uninitialized address.

##Units and Globally Available Variables
http://solidity.readthedocs.io/en/v0.4.21/units-and-global-variables.html

##visibility-and-getters
http://solidity.readthedocs.io/en/develop/contracts.html#visibility-and-getters