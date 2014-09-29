############################################################################### 
#
#  Nom     : G:\PS\ConvertForm\Demo\IseAddon\AddonForm.ps1  
#  Version : 0.1
#  Auteur  :
#  Date    : le 23/09/2014
#
#  G�n�r� sous PowerShell V3.0
#  Appel   : Convert-Form -Path G:\PS\ConvertForm\TestsWinform\AddonISE\AddonForm.Designer.cs -Destination G:\PS\ConvertForm\Demo\IseAddon -asFunction
################################################################################
#Requires -Version 3.0

#Recherche de d�pendances de commande
$OldPSMAP,$PSModuleAutoloadingPreference='All'
$script:RuntimeModules=@(
 'Microsoft.PowerShell.Core',
 'Microsoft.PowerShell.Diagnostics',
 'Microsoft.PowerShell.Host',
 'Microsoft.PowerShell.Management',
 'Microsoft.PowerShell.Security',
 'Microsoft.PowerShell.Utility',
 'Microsoft.WSMan.Management',
 'ISE',
 'PSDesiredStateConfiguration', #PS v4
 'PSScheduledJob',
 'PSWorkflow',
 'PSWorkflowUtility'
)

function Get-ScriptDirectory
{ #Return the directory name of this script
  $Invocation = (Get-Variable MyInvocation -Scope 1).Value
  Split-Path $Invocation.MyCommand.Path
}

$script:ScriptPath = Get-ScriptDirectory
."$script:ScriptPath\SelectModuleFrm.ps1"
$script:Functions = $script:Dependencies = $null

function Show-MessageBox([string] $Message,[string] $Titre="",  [String] $IconType="Information",[String] $BtnType="Ok")
{ 
  try 
  {
   [Windows.Forms.MessageBox]::Show($Message,$Titre, $BtnType,$IconType)
  }
  catch [System.Management.Automation.RuntimeException] {
   Throw "Assurez-vous que l'assembly [System.Windows.Forms] est bien charg�."       
  }
}
function Get-Token {
 #Renvoi tous les tokens de type Command
 #Renseigne la collection des scripts charg�s dans le code analys�  
 param($Tokens)  
 
  function AddScriptDependency
  {
      #L'analyse des op�rateur . et & n�cessite de connaitre le token suivant 
      #On r�cup�re le texte du token suivant
      #On poursuit la boucle avec le suivant : $Foreach.Current +1 
    [void]($Foreach.MoveNext())
    $TK=$Foreach.Current
     #Le suivant est une imbrication
    if ($Tk -is [System.Management.Automation.Language.StringExpandableToken]) 
    {
     if ($Tk.NestedTokens -ne $null)
     {
       Get-Token $Tk.NestedTokens
       continue
     }
    }
    if ( @('Identifier','LCurly','LParen','MemberName','Variable','Dollarparen','LineContinuation','Dot') -notContains $TK.Kind ) #Function ou Scriptblock ou regroupement
    {
      [void]$script:ScriptDependencies.Add($TK.Text)
      [void]$script:lstbxModules.Items.Add("D�pend du script : $($TK.Text)")
      Continue
    }
  }#AddScriptDependency       
 
 foreach ($Token in $Tokens)
 {
   Write-debug "Token=$($Token.Text)"
   #Note : TokenFlags est un champ de bit
   if ($Token -is [System.Management.Automation.Language.StringExpandableToken])
   {Get-Token $Token.NestedTokens}
   elseif ($Token.TokenFlags -band [System.Management.Automation.Language.TokenFlags]::CommandName)
   {
     if ($Token.TokenFlags -band [System.Management.Automation.Language.TokenFlags]::KeyWord)
     {continue}
     if ($Token.TokenFlags -band [System.Management.Automation.Language.TokenFlags]::BinaryOperator)
     {continue}
     if ($Token.TokenFlags -band [System.Management.Automation.Language.TokenFlags]::BinaryOperator)
     {continue}
     if ($Token.TokenFlags -band [System.Management.Automation.Language.TokenFlags]::UnaryOperator)
     {continue}
     if ($Token.TokenFlags -band [System.Management.Automation.Language.TokenFlags]::CaseSensitiveOperator)
     {continue}
     if ($Token.TokenFlags -band [System.Management.Automation.Language.TokenFlags]::AssignmentOperator)
     {continue}
     if ($Token.TokenFlags -band [System.Management.Automation.Language.TokenFlags]::PrefixOrPostfixOperator)
     {continue}
     if ($Token.Kind -eq 'Generic')
     { Write-output $Token.Value }
     elseif ($Token.Kind -eq 'Identifier') #C'est un alias
     {Write-output $Token.Text}
     elseif ($Token.Kind -eq 'Dot') #SpecialOperator
     { AddScriptDependency } 
     else
     { Write-Error "Type de token $($Token.Kind) � impl�menter '$Token'"}
   }
   elseif (($Token.TokenFlags -band [System.Management.Automation.Language.TokenFlags]::SpecialOperator) -and ($Token.Text -match '&|\.'))
   { AddScriptDependency }
 }
}#Get-Token

function GetDependencies{
 #todo :  Manifeste de module et Import-Module 
 #Les commandes des modules imbriqu�s n'ayant pas de r�pertoire d�di�( cf. $PSModulePath) ne sont pas 
 #list�es par Get-command, elles sont donc consid�r�es comme introuvables.
 #Dans ce cas $PSModuleAutoLoadingPreference ne peut pas retrouver le module. 
 #La recherche de d�pendances sur les variables de module n'est pas impl�ment�e

 param($Code)	

  function AddError {
    param($CmdName,$ExceptionMessage) 
    if (-not $UnknownCommands.Contains($CmdName))
    {
      [void]$script:lstbxErrors.Items.Add("'$CmdName' : commande introuvable.$ExceptionMessage")
      [void]$UnknownCommands.Add($CmdName)
      $script:lstbxErrors.Refresh()
    }        
  }#AddError
 	
  $script:ScriptDependencies = New-Object System.Collections.ArrayList
  $tokenAst = $parseErrorsAst = $null
  $scriptBlockAst = [System.Management.Automation.Language.Parser]::ParseInput($Code, [ref]$tokenAst, [ref]$parseErrorsAst)
  if ($parseErrorsAst.Count -ne 0)
  { 
    $parseErrorsAst|Foreach {write-host $_}
    [void](Show-MessageBox "The script contains syntax errors" "Parsing" "Error") 
    return
  }
  else
  {
     #Recherche les fonctions d�clar�es dans le code de l'onglet ISE courant
    $script:Functions=$scriptBlockAst.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true) |
                        Select-Object -ExpandProperty Name
    
    $Result=New-Object System.Collections.ArrayList
    $UnknownCommands=New-Object System.Collections.ArrayList
     #Recence toutes les commandes
    $AllCommands=@(Get-Command -All -EA Stop)
    
     #Recherche dans le code toutes les commandes
     #On ne peut savoir si une commande r�f�rencera tjr le m�me module
     #ou si une fonction(proxy) masquera un cmdlet lors de l'ex�cution du code. 
     Get-Token $TokenAst|
      Select -unique|
      Foreach-Object{
        $CommandName=$_
        Write-Debug "Analyse $CommandName $(get-date)"
        #On filtre les noms de fonction du script en cours d'analyse
        if ( (![string]::IsNullOrEmpty($CommandName)) -and ($script:Functions -NotContains $CommandName))
        {
           try {
               #Si le nom est complet dans ce cas il n'y a pas d'ambiguit�
             if ($CommandName.Contains('\') )
             {
                #En V3 gcm retourne une seule fonction, celle qui sera utilis�e par d�faut par PS
               $Command=Get-Command $CommandName -EA Stop  
               $CommandName=($CommandName -split '\\')[1]
             }  
             else
             {
                #Recherche/s�lection s'il y a ambiguit�
                  #Bug sur GCM -Name -All ??
               $Commands=@($AllCommands|Where Name -eq $CommandName)
               if ($Commands.Count -gt 1) 
               {
                  #La premi�re commande de la liste n'est pas celle qui sera utilis�e par d�faut par PS
                 $Command=SelectModuleForm $AddonFrm $script:ScriptPath "Command : $CommandName" $Commands
                 if ($Command -eq $null )
                 { return }
               }
               elseif ($Commands.Count -eq 1)  
               { $Command=$Commands[0] }
               elseif ($Commands.Count -eq 0) 
               { 
                  #Si la commande existe dans les modules core ce n'est pas une erreur
                 $Command=Get-Command $CommandName -EA Stop
                 if ($script:RuntimeModules -NotContains $Command.ModuleName) 
                 { 
                   AddError $CommandName
                   return #suivant 
                 }
               }
             }
             $ModuleName=$Command.ModuleName
             $Version=$Command.Module.Version

             if ( ![string]::IsNullOrEmpty($ModuleName) -and ($script:RuntimeModules -NotContains $ModuleName) )
             { 
                $ModuleReference="@{{ModuleName=`"{0}`";ModuleVersion='{1}'}}" -F $ModuleName,$Version
                [void]$script:lstbxModules.Items.Add("'$CommandName' d�pend du module : $ModuleName -> $($Command.Module.ModuleBase)")
                if (!$Result.Contains($ModuleReference))
                {
                  [void]$Result.Add($ModuleReference) 
                  $script:lstbxModules.Refresh()
                }
             }
           } 
           catch {
               AddError $CommandName "$_"
           }
        }#if
      }#foreach
   ,$Result  
  } #else
}

Function GenerateAddOnDependencyForm {
 param ( 
    [ValidateNotNullOrEmpty()]
    [Parameter(Position=0,Mandatory=$true)]
  [string] $ScriptPath
 )
# Chargement des assemblies externes
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$AddonFrm = New-Object System.Windows.Forms.Form

$components = New-Object System.ComponentModel.Container
$pnlBackground = New-Object System.Windows.Forms.Panel
$splitContainer = New-Object System.Windows.Forms.SplitContainer
$script:lstbxModules = New-Object System.Windows.Forms.ListBox
$script:lstbxErrors = New-Object System.Windows.Forms.ListBox
$toolTip1 = New-Object System.Windows.Forms.ToolTip($components)
$pnlBottom = New-Object System.Windows.Forms.Panel
$btnExecute = New-Object System.Windows.Forms.Button
$btnInsert = New-Object System.Windows.Forms.Button
$btnCancel = New-Object System.Windows.Forms.Button
#
# pnlBackground
#
$pnlBackground.Controls.Add($splitContainer)
$pnlBackground.Dock =[System.Windows.Forms.DockStyle]::Fill
$pnlBackground.Location = New-Object System.Drawing.Point(0, 0)
$pnlBackground.Name = "pnlBackground"
$pnlBackground.Size = New-Object System.Drawing.Size(414, 310)
$pnlBackground.TabIndex = 0
#
# splitContainer
#
$splitContainer.Dock =[System.Windows.Forms.DockStyle]::Fill
$splitContainer.Location = New-Object System.Drawing.Point(0, 0)
$splitContainer.Name = "splitContainer"
$splitContainer.Orientation =[System.Windows.Forms.Orientation]::Horizontal
#
# splitContainer.Panel1
#
$splitContainer.Panel1.Controls.Add($lstbxModules)
#
# splitContainer.Panel2
#
$splitContainer.Panel2.Controls.Add($lstbxErrors)
$splitContainer.Size = New-Object System.Drawing.Size(414, 310)
$splitContainer.SplitterDistance = 117
$splitContainer.TabIndex = 0
#
# lstbxModules
#
$script:lstbxModules.Dock =[System.Windows.Forms.DockStyle]::Fill
$script:lstbxModules.FormattingEnabled = $true
$script:lstbxModules.Location = New-Object System.Drawing.Point(0, 0)
$script:lstbxModules.Name = "lstbxModules"
$script:lstbxModules.Size = New-Object System.Drawing.Size(414, 117)
$script:lstbxModules.TabIndex = 0
$toolTip1.SetToolTip($lstbxModules, "module dependent commands")
#
# lstbxErrors
#
$script:lstbxErrors.Dock =[System.Windows.Forms.DockStyle]::Fill
$script:lstbxErrors.FormattingEnabled = $true
$script:lstbxErrors.Location = New-Object System.Drawing.Point(0, 0)
$script:lstbxErrors.Name = "lstbxErrors"
$script:lstbxErrors.Size = New-Object System.Drawing.Size(414, 189)
$script:lstbxErrors.TabIndex = 0
$toolTip1.SetToolTip($lstbxErrors, "Errors list.")
#
$pnlBottom.Controls.Add($btnCancel)
$pnlBottom.Controls.Add($btnInsert)
$pnlBottom.Controls.Add($btnExecute)
$pnlBottom.Dock =[System.Windows.Forms.DockStyle]::Bottom
$pnlBottom.Location = New-Object System.Drawing.Point(0, 254)
$pnlBottom.Name = "pnlBottom"
$pnlBottom.Size = New-Object System.Drawing.Size(414, 56)
$pnlBottom.TabIndex = 1
#
# btnExecute
#
$btnExecute.Location = New-Object System.Drawing.Point(25, 15)
$btnExecute.Name = "btnExecute"
$btnExecute.Size = New-Object System.Drawing.Size(75, 23)
$btnExecute.TabIndex = 0
$btnExecute.Text = "Execute"
$toolTip1.SetToolTip($btnExecute, "Search the dependenies modules")
$btnExecute.UseVisualStyleBackColor = $true

function OnClick_btnExecute {
 try {
  $AddonFrm.Cursor=[System.Windows.Forms.Cursors]::WaitCursor
  $btnCancel.Enabled = $false  
  $btnInsert.Enabled = $false
  if ($script:lstbxModules.Items.count -gt 0)
  { $script:lstbxModules.Items.Clear() }

  if ($script:lstbxErrors.Items.count -gt 0)
  { $script:lstbxErrors.Items.Clear() }
         
  $script:Dependencies=GetDependencies $psISE.CurrentFile.Editor.Text
  if ($script:Dependencies -eq $null)
  { $AddonFrm.Close() }
  else 
  {$btnInsert.Enabled = $true}
 } Finally {
   $AddonFrm.Cursor=[System.Windows.Forms.Cursors]::Default
   $btnCancel.Enabled = $true
 }
}
$btnExecute.Add_Click( { OnClick_btnExecute } )

#
# btnInsert
#
$btnInsert.DialogResult =[System.Windows.Forms.DialogResult]::OK
$btnInsert.Enabled = $false
$btnInsert.Location = New-Object System.Drawing.Point(157, 15)
$btnInsert.Name = "btnInsert"
$btnInsert.Size = New-Object System.Drawing.Size(75, 23)
$btnInsert.TabIndex = 1
$btnInsert.Text = "Insert"
$toolTip1.SetToolTip($btnInsert, "Insert dependencies in the current  tab")
$btnInsert.UseVisualStyleBackColor = $true

function OnClick_btnInsert {
  $OFS=','
  $Text=@"
#Requires -Version 3.0
$(
  if ($script:Dependencies.Count -gt 0)
  {"#Requires -Modules $script:Dependencies"}
)

$(
 $OFS=''
 "#Scripts required`r`n"
 foreach ($Script in $script:ScriptDependencies)
 {  "# $Script`r`n" }
)
`r`n
"@
 if ($PSDebugContext)
 {[void](Show-MessageBox $Text "New requirements" "Info") }
 else
 {
   $psISE.CurrentFile.Editor.SetCaretPosition(1,1)
   $psISE.CurrentFile.Editor.InsertText($Text)
 }
 $AddonFrm.Close()
}
$btnInsert.Add_Click( { OnClick_btnInsert } )

#
# btnCancel
#
$btnCancel.DialogResult =[System.Windows.Forms.DialogResult]::Cancel
$btnCancel.Location = New-Object System.Drawing.Point(303,15)
$btnCancel.Name = "btnCancel"
$btnCancel.Size = New-Object System.Drawing.Size(75, 23)
$btnCancel.TabIndex = 2
$btnCancel.Text = "Cancel"
$btnCancel.UseVisualStyleBackColor = $true

#
# AddonFrm
#
$AddonFrm.ClientSize = New-Object System.Drawing.Size(414, 310)
$AddonFrm.Controls.Add($pnlBottom)
$AddonFrm.Controls.Add($pnlBackground)
$AddonFrm.MinimumSize = New-Object System.Drawing.Size(430, 348)
$AddonFrm.Name = "AddonFrm"
$AddonFrm.Text = "Addon Dependencies"
$AddonFrm.StartPosition = "CenterScreen"
$toolTip1.SetToolTip($AddonFrm, "Retrieve dependencies of a script")

$AddonFrm.Add_Shown({$AddonFrm.Activate()})
$ModalResult=$AddonFrm.ShowDialog()
# Lib�ration de la Form
$AddonFrm.Dispose()
$PSModuleAutoloadingPreference=$OldPSMAP
}# GenerateAddOnDependencyForm

[void]$psISE.CurrentPowerShellTab.AddOnsMenu.Submenus.Add('Get dependencies', {GenerateAddOnDependencyForm $script:ScriptPath},'ALT+F8')
