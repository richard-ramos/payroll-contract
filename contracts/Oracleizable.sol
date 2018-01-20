pragma solidity ^0.4.18;

import "./Ownable.sol";

contract Oracleizable is Ownable {
  address public oracle;

  event ChangedOracle(address indexed previousOracle, address indexed newOracle);

  function Oracleizable(address _oracle) public {
    oracle = _oracle;
  }

  modifier onlyOracle() {
    require(msg.sender == oracle);
    _;
  }

  function changeOracle(address _newOracle) public onlyOwner {
    require(oracle != address(0x0));
    ChangedOracle(oracle, _newOracle);
    oracle = _newOracle;
  }

}














