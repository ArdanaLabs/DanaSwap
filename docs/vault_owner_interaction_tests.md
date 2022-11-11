Questions that need to be resolved:
 - Is the collateralization rate stored in the datum? We can compute it using other information, should that computation be done by the frontend?
 - Can a user deposit an amount collateral even if that amount is not sufficient to bring the vault in a healthy state?
 - Can a user during initialization configure the amount of collateral he/she wants, the amount of dUSD he/she wants, the collateralization rate or all three? Since the equation can be restrucured for any of these, we should decide what we want.

# Tests
## Vault
### Querying Vaults
#### Offchain
 - Querying for all vaults known by the protocol should return a list of all known vaults.
 - Querying for all vaults a user owns by passing the users public-key-hash returns a list of all of the user owned vaults.
 - Querying for vaults that are undercollaterized should return all undercollaterized vaults.
Note that for all the cases where no vault exists matching the criteria we expect an empty result, this means we need a specific test case covering this.
We also need to check whether all vault information is present when getting the query result, this includes:
 - the amount of collateral
 - the amount of dUSD (debt/credit)
 - the collateralization ratio
 - the vaults health score, TODO: what is this score? e.g. `liquidationRatio - collateralizationRatio` normalized?

#### UI
##### Functional
 - Visiting the "Vaults" page lists all the vaults owned by the visiting user.
 - Applying a filter to view undercollaterized vaults, lists all undercollaterized vaults owned by the visiting user.
 - Selecting a sort method on the list of owned vaults, like amount of collateral, debt, collateralization ratio, and vault health state, sorts the list accordingly.
 - Clicking on one of the enlisted vaults, shows more details about respective valut (TODO: what information are of interest) in form of a TODO popup/seperate page?
 - Unhealthy vaults should be visually highlighted (e.g. using a color like red).
 - While waiting for the vault list to be fetched a [Throbber](https://en.wikipedia.org/wiki/Throbber) should be displayed
 - If no vaults are available a respective informative text should be displayed
 - If no vaults are available the user should be offered to initialize his/her first vault
##### Non-Functional 
 - Applying a filter has immediate effect on the displayed list.
 - Applying a sort method has immediate effect on the displayed list.
 - The list should respond immediately to interactions.

### Initializing Vaults
#### Offchain
 - Initializing a vault if the last update time of the price-oracle was more than two hours ago should fail. Returning a descriptive message.
 - Initializing a vault given the provided collateral and collateralization ratio, succeeds only if the minimal amount of dUSD (debt) that is going to be minted is greater or equal the configured `Debt Floor` (i.e. min. amount of dUSD that is minted) which  is configured by the protocol. The opposite case if that criteria is not met should fail.
 - Initializing a vault given the provided collateral and desired amount of dUSD (debt) succeeds only if the minimal amount of dUSD that is going to be minted is greater or equal the configured `Debt Floor` (i.e. min. amount of dUSD that is minted) which  is configured by the protocol. The opposite case if that criteria is not met should fail.
 - Initializing a vault even though owning an undercollaterized vault should succeed, if the above `Debt Floor` criteria is met.
 - Initializing multiple vaults should succeed if the above `Debt Floor` criteria is met.
 - Successful initialization when setting the collateral amount and collateralization ratio should set compute the minted dUSD (debt) correctly.
 - Successful initialization when setting the collateral amount the desired dUSD (debt) should compute the collateralization ratio correctly.
 - Successful initialization associates that vault with the user who initialized it.
 - Successful initialization makes the protocol aware of that vault.
#### UI
##### Functional
 - Clicking on the `Initialize Vault` button opens up a page/popup with a form guiding through the vault initialization/configuration process.
 - The "Initialize Vault" page/popup shows the amount of the to be minted dUSD (debt/credit) given the entered collateralization amount.
 - The "Initialize Vault" page/popup prevents the user from initializing the vault, if he/she does not have sufficient funds in the wallet.
 - The "Initialize Vault" page/popup prevents the user from initializing the vault, if the entered collateral amount does not exceed the minimal collateralization rate.
 - The "Initialize Vault" pae/popup warns the user if the entered collateral amount does not exceed the minimal collateralization rate.
 - After the successful initialization the user is informed about success.
 - After the successful initialization the user is redirected to his owned vaults list.
 - If the vault initialization fails a descriptive error message is presented.
 - If the vault initialization fails the user is offered to try it again or cancel.
 - Retrying will reuse the previously entered data.
##### Non-Functional
 - Entering modifying the collateral amount has immediate effects on the vaults information displayed.

### Depositing Collateral to Vaults
#### Offchain
 - Depositing only succeeds if done by a user who is the owner of the vault. Test with non-owner.
 - Depositing a positive amount of collateral to the vault succeeds.
 - Depositing a negative amount should fail. Returning a descriptive error message.
 - Depositing 0 should fail. Returning a descriptive error message.
 - Depositing collateral to a undercollaterized vault should succeed (TODO: only if the vault will result in not being in a undercollaterized state?)
 - Successful depositing should increase the amount of collateral in the vault by the respective amount.
 - Successful depositing should update the collateralization ratio.
#### UI
##### Functional
 - Clicking the `Deposit` button opens up a page/popup with a form guiding the user through the process for depositing collateral to the vault.
 - The "deposit to vault" page/popup displays the current information about the vault the user wants to deposit to.
 - The "deposit to vault" page/popup displays a textfield allowing the user to specify an amount that should be deposited to the collateral.
 - Entering a invalid (negative or zero) amount should prevent the user to continue with the deposit process.
 - Entering a valid amount shows the effects on the vaults information transparently. (e.g. use diff color)
 - The "deposit to vault" page/popup displays a button to cancel the process.
 - Canceling the "deposit to vault" process returns the user to his vault list.
 - The "deposit to vault" page/popup displays a button to submit the deposit.
 - Submitting the deposit displays a Throbber while the transaction is being processed.
 - If the deposit transaction fails, a descriptive error message is shown.
 - If the deposit transaction fails, the user is offered to retry or cancel.
 - Retrying will reuse the previously entered data.
##### Non-Functional
 - Entering modifying the collateral amount has immediate effects on the vaults information displayed.

### Withdrawing Collateral from Vaults
#### Offchain
 - Withdrawing only succeeds if done by a user who is the owner of the vault. Test with non-owner.
 - Withdrawing a positive amount of collateral from the vault succeeds.
 - Withdrawing an amount of collateral that leaves the amount of collateral in the vault <= 0 fails.
 - Withdrawing an amount of collateral that leaves the collateralization ratio below the liquidation ratio should fail. TODO: this has contradictory specifications in the spec. in 2.2 we say only in the UI this should be forbidden in 3.2 there is a bullet saying that it does not work for both.
 - Withdrawing a negative amount should fail. Returning a descriptive error message.
 - Withdrawing 0 should fail. Returning a descriptive error message.
 - Withdrawing collateral from a non-undercollaterized vault should succeed.
 - Withdrawing collateral from an undercollaterized vault succeeds (TODO: only if the vault will result in not being in a undercollaterized state?)
 - Successful withdrawing should lower the amount of collateral in the vault by the respective amount.
 - Successful withdrawing should update the collateralization ratio.

#### UI
##### Functional
 - Clicking the `Withdraw` button opens up a page/popup with a form guiding the user through the process for withdrawing collateral from the vault.
 - The "withdraw from vault" page/popup displays the current information about the vault the user wants to withdraw from.
 - The "withdraw from vault" page/popup displays a textfield allowing the user to specify an amount that should be withdrawed from the collateral.
 - Entering an invalid (negative, zero, too high) amount should prevent the user to continue with the withdraw process.
 - Entering a valid amount shows the effects on the vaults information transparently. (e.g. use diff color)
 - The "withdraw from vault" page/popup displays a button to cancel the process.
 - Canceling the "withdraw from vault" process returns the user to his vault list.
 - The "withdraw from vault" page/popup displays a button to submit the withdrawal.
 - Submitting the withdrawal displays a Throbber while the transaction is being processed.
 - If the withdrawal transaction fails, a descriptive error message is shown.
 - If the withdrawal transaction fails, the user is offered to retry or cancel.
 - Retrying will reuse the previously entered data.
##### Non-Functional
 - Entering modifying the collateral amount has immediate effects on the vaults information displayed.

### Withdrawing dUSD (debt) from Vaults i.e. taking out a loan
#### Offchain
 - Withdrawing dUSD only succeeds if done by a user who is the owner of the vault. Test with non-owner.
 - Withdrawing dUSD from a vault only succeeds if the resulting debt amount in the vault is not element of `[0, Debt Foor]`. On failure it should return a descriptive error message.
 - Withdrawing a negative amount of dUSD should fail. Returning a descriptive error message.
 - Withdrawing an amount of dUSD that leaves the collateralization ratio below the liquidation ratio should fail. TODO: this has contradictory specifications in the spec. in 2.2 we say only in the UI this should be forbidden in 3.2 there is a bullet saying that it does not work for both.
 - Withdrawing dUSD from a non-undercollaterized vault should succeed.
 - Withdrawing dUSD from an undercollaterized vault succeeds TODO: should the user be able to do this
 - Successful withdrawing of dUSD should increase the amount of debt owed in the vault by the respective amount.
 - Successful withdrawing dUSD should update the collateralization ratio.
#### UI
##### Functional
 - Clicking the `Withdraw dUSD` button opens up a page/popup with a form guiding the user through the process for withdrawing dUSD from the vault.
 - The "withdraw dUSD from vault" page/popup displays the current information about the vault the user wants to withdraw dUSD from.
 - The "withdraw dUSD from vault" page/popup displays a textfield allowing the user to specify an amount of dUSD (debt) that should be withdrawn.
 - Entering an invalid (negative, zero, too high) amount should prevent the user to continue with the withdraw process.
 - Entering a valid amount shows the effects on the vaults information transparently. (e.g. use diff color)
 - The "withdraw dUSD from vault" page/popup displays a button to cancel the process.
 - Canceling the "withdraw dUSD from vault" process returns the user to his vault list.
 - The "withdraw dUSD from vault" page/popup displays a button to submit the withdrawal.
 - Submitting the withdrawal displays a Throbber while the transaction is being processed.
 - If the withdrawal transaction fails, a descriptive error message is shown.
 - If the withdrawal transaction fails, the user is offered to retry or cancel.
 - Retrying will reuse the previously entered data.
##### Non-Functional
 - Entering modifying the dUSD amount has immediate effects on the vaults information displayed.

### Depositing dUSD (debt) to Vaults i.e. paying back a loan
#### Offchain
 - Depositing dUSD only succeeds if done by a user who is the owner of the vault. Test with non-owner.
 - Depositing dUSD from a vault only succeeds if the resulting debt amount in the vault is not element of `[0, Debt Foor]`. On failure it should return a descriptive error message.
 - Depositing dUSD pays a stability fee to the buffer.
 - Depositing a negative amount of dUSD should fail. Returning a descriptive error message.
 - Depositing 0 should fail. Returning a descriptive error message.
 - Depositing dUSD to a undercollaterized vault should succeed (TODO: only if the vault will result in not being in a undercollaterized state?)
 - Successful depositing should lower the amount of debt owed in the vault by the respective amount.
 - Successful depositing should update the collateralization ratio.
#### UI
##### Functional
 - Clicking the `Deposit dUSD` button opens up a page/popup with a form guiding the user through the process for depositing dUSD to the vault.
 - The "deposit dUSD to vault" page/popup displays the current information about the vault the user wants to deposit dUSD to.
 - The "deposit dUSD to vault" page/popup displays a textfield allowing the user to specify an amount of dUSD (debt) that should be deposited.
 - Entering an invalid (negative, zero) amount should prevent the user to continue with the deposit process.
 - Entering a valid amount shows the effects on the vaults information transparently. (e.g. use diff color)
 - The "deposit dUSD to vault" page/popup displays a button to cancel the process.
 - Canceling the "deposit dUSD to vault" process returns the user to his vault list.
 - The "deposit dUSD to vault" page/popup displays a button to submit the deposit.
 - Submitting the deposit displays a Throbber while the transaction is being processed.
 - If the deposit transaction fails, a descriptive error message is shown.
 - If the deposit transaction fails, the user is offered to retry or cancel.
 - Retrying will reuse the previously entered data.
##### Non-Functional
 - Entering modifying the dUSD amount has immediate effects on the vaults information displayed.

## Vault Integration Tests
