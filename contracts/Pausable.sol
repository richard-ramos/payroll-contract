pragma solidity ^0.4.18;

import "./Ownable.sol";

contract Pausable is Ownable {

	bool internal paused;

    event LogPausedSet(address indexed sender, bool indexed newPausedState);

	modifier onlyUnpaused(){
		if(paused) revert();
		_;
	}

	modifier onlyPaused(){
		if(!paused) revert();
		_;
	}

	function Pausable(bool initialState){
		paused = initialState;
	}

	function setPaused(bool newState) 
		onlyOwner
		public 
		returns(bool success)
    {
		require(paused != newState);
		paused = newState;
		LogPausedSet(msg.sender, newState);

		return true;
	}

	function isPaused() 
	    public 
		constant 
		returns(bool isIndeed){
		return paused;
	}

}