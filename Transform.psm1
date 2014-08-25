# PowerShell ConvertForm 
# Transform module
# Objet   : Regroupe des fonctions de transformation de 
#           code CS en code PowerShell.

#todo la g�n�ration de code peut utiliser des string localis�es.

 #Cr�ation du header
."$psScriptRoot\Tools\Add-Header.ps1"

function Convert-DictionnaryEntry($Parameters) 
{   #Converti un DictionnaryEntry en une string "cl�=valeur cl�=valeur..." 
  "$($Parameters.GetEnumerator()|% {"$($_.key)=$($_.value)"})"
}#Convert-DictionnaryEntry

function Backup-Collection($Collection,$Message)
{ #Sauvegarde dans un fichier temporaire unique le contenu de la collection de lignes en cours d'analyse
  if ( $DebugPreference -ne "SilentlyContinue") 
  { 
   if  ($Collection -is  [System.Collections.IEnumerable])
   {
     $TempFile = [IO.Path]::GetTempFileName()
     $Collection|Set-Content $TempFile
     Write-Debug $Message
     Write-Debug "Sauvegarde dans le fichier temporaire : $TempFile"
   } 
  else {Write-Warning "Backup-Collection : La variable `$Collection n'est pas une collection d'objet."} 
  }
}

Function Add-LoadAssembly{
 param (
  [System.Collections.ArrayList] $Liste,
  [String[]] $Assemblies
 )
 #Charge une liste d'assemblies .NET 
 #On les suppose pr�sent dans le GAC
 #Add-Type -Path "FullPath\filename.dll" 
 foreach ($Assembly in $Assemblies)
 { [void]$Liste.Add("Add-Type -AssemblyName $Assembly") }
 [void]$Liste.Add("")
}

Function Add-EventComponent([String] $ComponentName, [String] $EventName)
{ #Cr�e et ajoute un �v�nement d'un composant.
  #Par d�faut le scriptbloc g�n�r� affiche un message d'information

  $UnderConstruction = "[void][System.Windows.Forms.MessageBox]::Show(`"L'�v�nement $ComponentName.Add_$EventName n'est pas impl�ment�.`")"
   #La syntaxe d'ajout d'un d�l�gu� est : Add_NomEv�n�ment 
   # o� le nom de l'�v�nement est celui du SDK .NET
   #On construit le nom de la fonction appell�e par le gestionnaire d'�v�nement
  $OnEvent_Name="On{0}_{1}" -f ($EventName,$ComponentName)
  $Fonction ="function $OnEvent_Name {{`r`n`t{0}`r`n}}`r`n" -f ($UnderConstruction)
   #On double le caract�re '{' afin de pouvoir l'afficher
  $EvtHdl= "`${0}.Add_{1}( {{ {2} }} )`r`n" -f ($ComponentName, $EventName, $OnEvent_Name)
# Here-string    
@"
$Fonction
$EvtHdl
"@
}

function Add-SpecialEventForm([String] $FormName)
{ # Ajoute des m�thodes d'�v�nement sp�cifiques � la forme principale
  #FormClosing
    # Permet � l'utilisateur de : 
    #   -d�terminer la cause de la fermeture
    #   -autoriser ou non la fermeture

 $Ent�te = "function OnFormClosing_{0}{{" -f ($FormName)
 $Close  = "`${0}.Add_FormClosing( {{ OnFormClosing_{0}}} )" -f ($FormName)

  #FormShown
 $CallHidefnct=""
 If ($HideConsole)
   #On affiche la fen�tre mais on cache la console 
  {$CallHidefnct="Hide-PSWindow;"}
   #Replace au premier plan la fen�tre en l'activant.
   # Form1.topmost=$true est inop�rant
 $Shown  = "`${0}.Add_Shown({{{1}`${0}.Activate()}})" -f ($FormName,$CallHidefnct)

# Here-string  
@"
$Ent�te 
`t# `$this est �gal au param�tre sender (object)
`t# `$_ est �gal au param�tre  e (eventarg)

`t# D�terminer la raison de la fermeture :
`t#   if ((`$_).CloseReason -eq [System.Windows.Forms.CloseReason]::UserClosing)

`t#Autorise la fermeture
`t(`$_).Cancel= `$False
}
$Close
$Shown
"@
}

function Add-ManageRessources{
 #Ajoute le code g�rant un fichier de ressources et ce � l'aide d'une "here-string"
  # 1 fonction
  # 2 test d'existence du fichier
  # 3 r�cup�ration dans une hastable des ressources de la Winform

# Here-string   
 param (
  [string] $SourceName
 )
 
@"

function Get-ScriptDirectory
{  #Renvoi le nom du r�pertoire d'un script parent, celui appel� sur la ligne de commande.
   # By J.Snover
  `$Invocation = (Get-Variable MyInvocation -Scope 1).Value
  Split-Path `$Invocation.MyCommand.Path
}

`$ScriptPath = Get-ScriptDirectory
`$RessourcesPath= Join-Path `$ScriptPath "$SourceName.resources"
if ( !(Test-Path `$RessourcesPath))
 {
  Write-Warning "Le fichier de ressources n'existe pas :``n``r `$RessourcesPath"
  break; # Sinon le script est en exception qq lignes plus tard
 }

  #Gestion du fichier des ressources
`$Reader = new-Object System.Resources.ResourceReader("`$RessourcesPath")
`$Ressources=@{}
`$Reader.GetEnumerator()|% {`$Ressources.(`$_.Name)=`$_.value}
 
 # Cr�ation des composants
"@         
}#Add-ManageRessources

function Convert-Enum([String] $Enumeration)
{ #Converti une valeur d'�num�ration
  # un.deux.trois en [un.deux]::trois
 $Enumeration = $Enumeration.trim()
  # recherche (et capture) en fin de cha�ne un mot pr�c�d� d'un point lui-m�me pr�c�d� de n'importe quel caract�res
 $Enumeration -replace "(.*)\.(\w+)$", '[$1]::$2'
}

function Select-ParameterEnumeration([String]$NomEnumeration, [String] $Parametres)
{ #Voir le fichier  "..\Documentations\Analyse des propri�t�s.txt"
 #G�re les propri�t�s Font et Anchor

  $Valeurs= $Parametres.Split("|")
  $NbValeur = $Valeurs.Count
   
   #Une seule valeur, on la convertie
  if ($NbValeur -eq 1 )
  { return Convert-Enum $Parametres} 

   #Valeur 1 :
   #         ((Nom.Enumeration)((Nom.Enumeration.VALEUR
    # recherche (et capture) en fin de cha�ne un mot pr�c�d� d'un point lui-m�me pr�c�d� de n'importe quel caract�res
  $Valeurs[0]= ($Valeurs[0] -replace "^.*\.(.*)$", '$1').Trim()
 
   #Valeur 2..n :
   #     Nom.Enumeration.VALEUR)    
   # recherche (et capture) en fin de cha�ne une parenth�se pr�c�d�e de caract�res uniquement pr�c�d�s d'un point lui-m�me pr�c�d� de n'importe quel caract�res
  for ($i=1;$i -le $NbValeur-2;$i++)
  { $Valeurs[$i]= ($Valeurs[$i] -replace "^.*\.([a-zA-Z]*)\)$", '$1').Trim() }

   #Derni�re valeur  :
   #         Nom.Enumeration.VALEUR))  
   # ou      Nom.Enumeration.VALEUR)))  
   # recherche (et capture) en fin de cha�ne deux parenth�ses pr�c�d�es de caract�res ou de chiffre uniquement pr�c�d�s d'un point lui-m�me pr�c�d� de n'importe quel caract�res
  $Valeurs[$NbValeur-1]= ($Valeurs[$NbValeur-1] -replace "^.*\.([a-zA-Z0-9]+)\)+$", '$1').Trim()
  return "[$NomEnumeration]`"{0}`"" -F ([string]::join(",", $Valeurs))
}

function Select-PropertyFONT([System.Text.RegularExpressions.Match] $MatchStr)
{ #Analyse une d�claration d'une propri�t� Font
   #Pour la cha�ne:  $label1.Font = New-Object System.Drawing.Font("Arial Black", 9.75F, System.Drawing.FontStyle.Bold, System.Drawing.GraphicsUnit.Point, ((byte)(0)))
	# $MatchStr contient 4 groupes :
	#  0- la ligne compl�te
	#  1- $label1
	#  2- .Font = New-Object System.Drawing.Font(
	#  3- "Arial Black", 9.75F, System.Drawing.FontStyle.Bold, System.Drawing.GraphicsUnit.Point, ((byte)(0))

    #R�cup�re les param�tres du constructeur
  $Parametres= [Regex]::Split($MatchStr.Groups[3].value,",")
    #Le premier est tjr le nom de la fonte de caract�re
    #Le second est tjr la taille de la fonte de caract�re dans ce cas on supprime le caract�re 'F' 
    #indiquant un type double
  $Parametres[1]=$Parametres[1] -replace "F",''
  
   #Teste les diff�rentes signatures de constructeurs
   #On parcourt toute la liste du nombre de param�tre possibles, les uns � la suite des autres.
  Switch ($Parametres.count)
  { 
    {$_ -eq 3} {  #Est-ce un param�tre de type System.Drawing.GraphicsUnit ?
                 if ( $Parametres[2].Contains("System.Drawing.GraphicsUnit") )
         		 {$Parametres[2]=Convert-Enum $Parametres[2]}
         		   #si non c'est donc un param�tre de type System.Drawing.FontStyle ?
       			 else { $Parametres[2]=Select-ParameterEnumeration "System.Drawing.FontStyle" $Parametres[2] }
     		   }

    {$_ -ge 4} {  #Le troisi�me est tjr de type FontStyle
   	   			  #Le quatri�me est tjr de type GraphicsUnit
                 $Parametres[2]= Select-ParameterEnumeration "System.Drawing.FontStyle" $Parametres[2]
                 $Parametres[3]=Convert-Enum $Parametres[3]
               }
                 
    {$_ -ge 5} {  #On r�cup�re uniquement la valeur du param�tre : ((byte)(123))
                  # Un ou plusieurs chiffres :                        [0-9]+
                 $Parametres[4]=$Parametres[4] -replace "\(\(byte\)\(([0-9]+)\)\)", '$1' 
               }

    #6 Le sixi�me (true - false) est trait� par la suite dans le script principal

                  #Pb :/
    {$_ -ge 7} { throw ("Cas impr�vu : {0}" -f ($MatchStr.Groups[3].value)) }
  }
  
  return $Parametres
}
function Select-PropertyANCHOR([System.Text.RegularExpressions.Match] $MatchStr)
{ #Analyse une d�claration d'une propri�t� Anchor
   #Pour la cha�ne: $comboBox1.Anchor = ((System.Windows.Forms.AnchorStyles)((((System.Windows.Forms.AnchorStyles.Top | System.Windows.Forms.AnchorStyles.Bottom)| System.Windows.Forms.AnchorStyles.Left)| System.Windows.Forms.AnchorStyles.Right)));

	# $MatchStr contient 4 groupes :
	#  0- la ligne compl�te
	#  1- $comboBox1
	#  2- .Anchor = ((System.Windows.Forms.AnchorStyles)
	#  3- (((System.Windows.Forms.AnchorStyles.Top | System.Windows.Forms.AnchorStyles.Bottom)| System.Windows.Forms.AnchorStyles.Left)| System.Windows.Forms.AnchorStyles.Right));

 #Peut �tre cod� dans l'appelant mais cela documente un peu plus
 return Select-ParameterEnumeration "System.Windows.Forms.AnchorStyles" $MatchStr.Groups[3].value
}

function Select-PropertyShortcutKeys([System.Text.RegularExpressions.Match] $MatchStr)
{ #Analyse une d�claration d'une propri�t� ShortcutKeys
   #Pour la cha�ne: this.toolStripMenuItem2.ShortcutKeys = ((System.Windows.Forms.Keys)((System.Windows.Forms.Keys.Alt | System.Windows.Forms.Keys.A)));

	# $MatchStr contient 4 groupes :
	#  0- la ligne compl�te
	#  1- $comboBox1
	#  2- .ShortcutKeys = ((System.Windows.Forms.Keys)
	#  3- ((System.Windows.Forms.Keys.Alt | System.Windows.Forms.Keys.A)));

 #Peut �tre cod� dans l'appelant mais cela documente un peu plus
 return Select-ParameterEnumeration "System.Windows.Forms.Keys" $MatchStr.Groups[3].value
}

function Select-ParameterRGB([System.Text.RegularExpressions.Match] $MatchStr)
{ #Analyse les param�tres d'un appel de la m�thode FromArgb
   #Pour la cha�ne:  $Case�Cocher.FlatAppearance.MouseDownBackColor = System.Drawing.Color.FromArgb(((int)(((byte)(192)))), ((int)(((byte)(255)))), ((int)(((byte)(192)))))
	# $MatchStr contient 4 groupes :
	#  0- la ligne compl�te
	#  1- $Case�Cocher.FlatAppearance.MouseDownBackColor
	#  2-  = System.Drawing.Color.FromArgb(
	#  3- ((int)(((byte)(192)))), ((int)(((byte)(255)))), ((int)(((byte)(192))))
	 
    #R�cup�re les 3 param�tres
  $Parametres= [Regex]::Split($MatchStr.Groups[3].value,",")
  for ($i=0; $i -lt $Parametres.count; $i++)
	  # On r�cup�re uniquement la valeur du param�tre : ((int)(((byte)(192))))
	  #Recherche ( et capture) en d�but de chaine une suite de caract�re suivis d'une parenth�se suivi de 
	  #un ou plusieurs chiffres suivis par une ou plusieurs parenth�ses
  { $Parametres[$i]=$Parametres[$i]  -replace "^(.*)\(([0-9]+)\)+", '$2' }
   
  return $Parametres
}

function ConvertTo-StringBuilder([System.Text.RegularExpressions.Match] $MatchStr, [Array] $NumerosOrdonnes)
 {  #On reconstruit le d�but d'une cha�ne � partir d'une expression pars�e
   # $NumerosOrdonnes : Contient les num�ros des groupes � ins�rer dans la nouvelle cha�ne
   $Result=new-object System.Text.StringBuilder
   foreach ($Num in $NumerosOrdonnes)
   { [void]$Result.Append($MatchStr.Groups[$Num].value) }
   return $Result
 }
 
function ConvertTo-Line([System.Text.RegularExpressions.Match] $MatchStr, [Array] $NumerosOrdonnes,[string[]] $Parametres )
{ #Utilis� pour reconstruire une propriet�.

   #On reconstruit l'int�gralit� d'un cha�ne pars�e et transform�e
  $Sb=ConvertTo-StringBuilder $MatchStr $NumerosOrdonnes
  [void]$Sb.Append( [string]::join(",", $Parametres)) 
  return $Sb.ToString()
}

function New-FilesName{
  #Construit les paths et noms de fichier � partir de $Source et $Destination
 param(
   [string] $ScriptPath,
    
   [System.IO.FileInfo]$SourceFI,
   
    #PSPathInfo ou string
   $Destination
 )

  #Le fichier de ressource poss�de une autre construction que le nom du fichier source
  #On garde le nom de la Form car on peut avoir + fichiers .Designer.cs
   # en entr�e                 : -Source C:\VS\Projet\PS\Form1.Designer.cs -Destination C:\Temp\Destination.ps1
   # fichier ressource associ� : C:\VS\Projet\PS\Form1.resx        
   # fichier ressource g�n�r�  : C:\Temp\Form1.ressources
   # fichier de log g�n�r�     : C:\Temp\Destination.Log
  $ProjectPaths=@{
     Source=$SourceFI.FullName
     SourcePath = $SourceFI.DirectoryName
     SourceName = ([System.IO.Path]::GetFilenameWithoutExtension($SourceFI.FullName)) -replace ".designer",''
  }
 
  if ($Destination -eq [String]::Empty)
  { 
      #Construit le nom � partir du nom de fichier source
     $ProjectPaths.Destination="$($ProjectPaths.SourcePath)\$($ProjectPaths.SourceName).ps1"
  }
  else 
  { 
      #R�cup�re le nom analys�
     $ProjectPaths.Destination=$Destination.GetFileName()
     if ([System.IO.Path]::GetExtension($ProjectPaths.Destination) -eq [string]::Empty)
     {
        $ProjectPaths.Destination=[System.IO.Path]::ChangeExtension($ProjectPaths.Destination,".ps1")
        Write-Verbose "L'extension .ps1 a �t� ajout� au nom du fichier Destination."
     }
  }

  $DestinationFI=New-object System.IO.FileInfo $ProjectPaths.Destination
  $ProjectPaths.DestinationPath = $DestinationFI.DirectoryName
  $ProjectPaths.DestinationName = ([System.IO.Path]::GetFilenameWithoutExtension($DestinationFi.FullName))

  Write-Debug 'BuildFiles ProjectPaths :' ; Convert-DictionnaryEntry $ProjectPaths|Foreach {Write-Debug $_}
  Write-Verbose "Le fichier source : $($ProjectPaths.Source)"
  Write-Verbose "Le fichier destination  : $($ProjectPaths.Destination)"
  
  $ProjectPaths 
} #New-FilesName

function New-RessourcesFile{ 
#Compile le fichier contenant les ressources d'un formulaire, ex : Form1.resx
 param (
  $ProjectPaths
 ) 
  
  write-Debug "Compile les ressources"
   #On g�n�re le fichier de ressources
   #todo + versions de resgen ?
   #todo error ou warning ?
  $Resgen="$psScriptRoot\ResGen.exe" 
  if ( !(Test-Path $Resgen))
  { write-host "Le programme g�n�rant les ressources est introuvable : $Resgen" -F DarkYellow }
  else
  {
	 $SrcResx = Join-Path $ProjectPaths.SourcePath ($ProjectPaths.SourceName+".resx")
	 if ( !(Test-Path $SrcResx))
	 { Write-Host "Le fichier de ressources est introuvable : $SrcResx" -F DarkYellow }
	 else
	 {
	   $DestResx = Join-Path $ProjectPaths.DestinationPath ($ProjectPaths.SourceName+".resources")
	   $Log=Join-Path $ProjectPaths.DestinationPath ("$($ProjectPaths.DestinationName).log")
	   if ((Test-Path $Log))
	   { 
	      trap  
          {Write-Warning "Suppression du fichier impossible : $Log"; Continue}
	      Remove-Item $Log 
	   }
	     #Message de debug
       "Resgen","SrcResx","DestResx","Log"|Gv |% {Write-Debug ("{0}={1}" -F $_.Name,$_.Value)}
	 
	    #Redirige le handle d'erreur vers le handle standard de sortie
	   $ResultExec=.$Resgen $SrcResx $DestResx 2>&1
	   $ResultExec|Out-File -width 999 $Log
	   if ($LastExitCode -ne 0)
	   { Write-Warning "Erreur($LastExitCode) lors de la g�n�ration du fichier de ressources . Consultez le fichier $log" }
	   else 
       { Write-Verbose "G�n�ration du fichier de ressources $DestResx`r`n" }
	 }
  } 
}

function Add-ErrorProvider([String] $ComponentName, [String] $FormName)
{ #Ajoute le texte suivant apr�s la ligne de cr�ation de la form,
  #le component ErrorProvider r�f�rence la Form contenant les composants qu'il doit g�rer
   
  #  #
  #  # errorProviderX
     #
  #  $errorProviderX.ContainerControl = $Form1

# Here-string  
@"
`#
`# $ComponentName
`#
$("`${0}.ContainerControl = `${1}" -F $ComponentName,$FormName)  
"@
} #Add-ErrorProvider

function Add-TestApartmentState {
  #Le switch -STA est d�tect�,, on ajoute un test sur le mod�le du thread courant.
@"

 #Utiliser le param�tre -STA.
if ([System.Threading.Thread]::CurrentThread.GetApartmentState() -ne [System.Threading.ApartmentState]::STA )
{Throw "Le script courant n�cessite que le mod�le du thread actuel soit [System.Threading.ApartmentState]::STA (Single Thread Apartment)." }

"@
} #Add-TestApartmentState

function Clear-KeyboardBuffer {
 while ($Host.UI.RawUI.KeyAvailable) 
 { $null=$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown, IncludeKeyUp")}
}

function Read-Choice{
  param(
      $Caption, 
      $Message,
        [ValidateSet("Yes","No")]
      $DefaultChoice="No"
  )
  
  Clear-KeyboardBuffer
  $Yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes"
  $No = New-Object System.Management.Automation.Host.ChoiceDescription "&No"
  $Choices = [System.Management.Automation.Host.ChoiceDescription[]]($Yes,$No)
  $Host.UI.PromptForChoice($Caption,$Message,$Choices,([byte]($DefaultChoice -eq "no")))
}
