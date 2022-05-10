# Advanced Sample Hardhat Project

This project demonstrates an advanced Hardhat use case, integrating other tools commonly used alongside Hardhat in the ecosystem.

# SuperApp rules

1) Super Apps cannot revert in the termination callback (afterAgreementTerminated())
Use the trycatch pattern if performing an action which interacts with other contracts inside of the callback. Doing things like transferring tokens without using the trycatch pattern is dangerous and should be avoided.
Double check internal logic to find any revert possibility.

2) Super Apps can't became insolvent.
Check if any interaction can lead to insolvency situation.
What is an insolvency situation? This occurs when a Super App tries to continue sending funds that it no longer has. Its super token balance must stay > 0 at minimum. You can learn more about liquidation & solvency in our section on this topic.

3) Gas limit operations within the termination callback (afterAgreementTerminated())
There is a limit of gas limit send in a callback function (3000000 gas units)
If the Super App reverts on terminations calls because of an out-of-gas error, it will be jailed.
For legitimate cases where the app reverts for out-of-gas (below the gas limit), the Super App is subject to user decision to send a new transaction with more gas. If the app still reverts, it will be jailed.
To protect against these cases, don't create Super Apps that require too much gas within the termination callback.

4) Incorrect ctx (short for context) data within the termination callback
Any attempt to tamper with the value of ctx or failing to give the right ctx will result in a Jailed App.
Any time a protocol function returns a ctx, that ctx should be passed to the next called function. It will repeat this process even in the return of the callback itself.
For more information on ctx and how it works you can check out our tutorial on userData.