# Ripple USD XRP Ledger Settings

On the XRP Ledger, a stablecoin is created by an issuer holding real-world assets as collateral, and creating equivalent tokens on the ledger. Users establish a trust line with the issuer to receive, hold, and transfer issued Ripple USD (RLUSD) tokens.

Ripple's stablecoin implementation utilizes the fungible tokens functionality that is native to the XRP Ledger.

## XRP Ledger flags

| Ledger Flag                 | Description                                                                                | Enabled |
| :-------------------------- | :----------------------------------------------------------------------------------------- | :-----: |
| `lsfGlobalFreeze`           | Freezes all assets issued by the account.                                                  |   ✅    |
| `lsfNoFreeze`               | Permanently give up the ability to freeze individual trust lines or disable global freeze. |   ❌    |
| `lsfRequiredAuth`           | Require authorization for users to hold balances issued by this address.                   |   ❌    |
| `lsfAllowTrustLineClawback` | Allows an account to claw back tokens it has issued.                                       |   ✅    |
| `lsfAccountTxnID`           | Track the ID of an account's most recent transaction.                                      |   ❌    |
| `lsfDepositAuth`            | Enable deposit authorization on this account.                                              |   ✅    |
| `lsfRequireDest`            | Require a destination tag for incoming payments.                                           |   ❌    |
| `lsfDefaultRipple`          | Enable rippling on the an account's trust lines by default.                                |   ✅    |
| `lsfDisallowXRP`            | XRP should not be sent to this account.                                                    |   ✅    |
| `lsfTickSize`               | An account-level setting and applies to all tokens issued by the same address.             |   ✅    |

For more information see the official [XRP Ledger documentation](https://xrpl.org/docs/concepts/tokens/fungible-tokens/stablecoins/configuration/).
