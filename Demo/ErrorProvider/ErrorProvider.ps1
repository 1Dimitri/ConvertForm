
################################################################################ 
#
#  Nom     : ErrorProvider.ps1
#
# Le premier textbox doit contenir du texte pouvant �tre converti en un entier positif.
# Le second textbox n'a pas de contrainte de validation.
#
#
################################################################################

# Chargement des assemblies externes
[void][Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
[void][Reflection.Assembly]::LoadWithPartialName("System.Drawing")

$components = new-object System.ComponentModel.Container
$btnClose = new-object System.Windows.Forms.Button
$TxtBoxSaisirNombre = new-object System.Windows.Forms.TextBox
$errorProvider1 = new-object System.Windows.Forms.ErrorProvider($components)
$lblSaisirNombre = new-object System.Windows.Forms.Label
$textBox1 = new-object System.Windows.Forms.TextBox
$lblAllText = new-object System.Windows.Forms.Label
#
# btnClose
#
$btnClose.Location = new-object System.Drawing.Point(183, 203)
$btnClose.Name = "btnClose"
$btnClose.Size = new-object System.Drawing.Size(60, 26)
$btnClose.TabIndex = 0
$btnClose.Text = "Close"
$btnClose.UseVisualStyleBackColor = $true
function OnClick_btnClose($Sender,$e){
    $Form1.Close()
}

$btnClose.Add_Click( { OnClick_btnClose $btnClose $EventArgs} )
#
# TxtBoxSaisirNombre
#
$TxtBoxSaisirNombre.Location = new-object System.Drawing.Point(12, 65)
$TxtBoxSaisirNombre.Name = "TxtBoxSaisirNombre"
$TxtBoxSaisirNombre.Size = new-object System.Drawing.Size(220, 20)
$TxtBoxSaisirNombre.TabIndex = 1
function OnEnter_TxtBoxSaisirNombre{
#Ev�nement d�clench� lorsque le composant devient le controle actif de la form.

 #D�sactive l'icone d'erreur s'il est pr�sent
 $errorProvider1.SetError($TxtBoxSaisirNombre, "")
}

$TxtBoxSaisirNombre.Add_Enter( { OnEnter_TxtBoxSaisirNombre } )
function OnValidating_TxtBoxSaisirNombre{
#Ev�nement d�clench� lors de la validation, d�s que le composant perd le focus.

  trap  [System.FormatException]
   { 
      #Active l'icone d'erreur en cas d'erreur de conversion d'un texte en un entier
     $errorProvider1.SetError($TxtBoxSaisirNombre, "Le texte saisie n'est pas un nombre.")
     Continue
   }
    #Parse le texte saisie
   [int32] $x = [Int32]::Parse($TxtBoxSaisirNombre.Text)
}

$TxtBoxSaisirNombre.Add_Validating( { OnValidating_TxtBoxSaisirNombre } )
# lblSaisirNombre
#
$lblSaisirNombre.AutoSize = $true
$lblSaisirNombre.Location = new-object System.Drawing.Point(12, 49)
$lblSaisirNombre.Name = "lblSaisirNombre"
$lblSaisirNombre.Size = new-object System.Drawing.Size(109, 13)
$lblSaisirNombre.TabIndex = 2
$lblSaisirNombre.Text = "&Saisissez un nombre :"
#
# textBox1
#
$textBox1.Location = new-object System.Drawing.Point(12, 120)
$textBox1.Name = "textBox1"
$textBox1.Size = new-object System.Drawing.Size(220, 20)
$textBox1.TabIndex = 3
#
# lblAllText
#
$lblAllText.AutoSize = $true
$lblAllText.Location = new-object System.Drawing.Point(12, 104)
$lblAllText.Name = "lblAllText"
$lblAllText.Size = new-object System.Drawing.Size(116, 13)
$lblAllText.TabIndex = 4
$lblAllText.Text = "Saisie sans contrainte :"
#
$Form1 = new-object System.Windows.Forms.form
#
# errorProvider1
#
$errorProvider1.ContainerControl = $Form1
#
#
$Form1.ClientSize = new-object System.Drawing.Size(292, 266)
$Form1.Controls.Add($lblAllText)
$Form1.Controls.Add($textBox1)
$Form1.Controls.Add($lblSaisirNombre)
$Form1.Controls.Add($TxtBoxSaisirNombre)
$Form1.Controls.Add($btnClose)
$Form1.Name = "Form1"
$Form1.Text = "Form1"
function OnFormClosing_Form1($Sender,$e){ 
    # $this est �gal au param�tre sender (object)
    # $_ est �gal au param�tre  e (eventarg)

    # D�terminer la raison de la fermeture :
    #   if (($_).CloseReason -eq [System.Windows.Forms.CloseReason]::UserClosing)

    #Autorise la fermeture
    ($_).Cancel= $False
}
$Form1.Add_FormClosing( { OnFormClosing_Form1 $Form1 $EventArgs} )
$Form1.Add_Shown({$Form1.Activate()})
$Form1.ShowDialog()
 #Lib�ration des ressources
$Form1.Dispose()


