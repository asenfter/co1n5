# Solidity

Best practice
https://github.com/ConsenSys/smart-contract-best-practices/#circuit-breakers-pause-contract-functionality


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