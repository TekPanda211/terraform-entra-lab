\# Before You Begin



Most Blackknight One commands require an authenticated Microsoft Graph session.



\## Import the Platform



```powershell

Import-Module .\\scripts\\PowerShell\\Platform\\Blackknight-Platform.psm1 -Force

```



\## Connect to Microsoft Graph



```powershell

Connect-BKGraph

```



A Microsoft sign-in window appears.



Authenticate using an account that has access to the Microsoft Entra tenant you wish to assess.



> \[!IMPORTANT]

> If your account has access to multiple Microsoft Entra tenants, verify the active tenant before running discovery commands.



Verify the connection:



```powershell

Get-MgContext |

&#x20;   Select-Object `

&#x20;       Account,

&#x20;       TenantId,

&#x20;       Environment,

&#x20;       AuthType,

&#x20;       Scopes

```



Verify through Blackknight One:



```powershell

Get-BKTenant

```



\## Connect to a Specific Tenant



```powershell

Connect-BKGraph `

&#x20;   -TenantId "<TenantId>"

```



\## Connect to a National Cloud



View supported environments.



```powershell

Get-MgEnvironment

```



Example:



```powershell

Connect-BKGraph `

&#x20;   -TenantId "<TenantId>" `

&#x20;   -Environment "Global"

```



\## Disconnect



```powershell

Disconnect-MgGraph

```



Reconnect:



```powershell

Connect-BKGraph

```

