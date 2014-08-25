using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Text;
using System.Windows.Forms;

namespace PSDrapAndDrop
{
    public partial class FrmMain : Form
    {
        public FrmMain()
        {
            InitializeComponent();
        }

        private void lstBxGauche_DragDrop(object sender, DragEventArgs e)
        {
            //On r�cup�re les donn�es de type fichier uniquement
            if (e.Data.GetDataPresent(DataFormats.FileDrop))
            {
                 //Un ou plusieurs fichiers
                string[] Fichiers = (string[])e.Data.GetData(DataFormats.FileDrop);

                // Effectue l'op�ration de drag-and-drop, 
                // ici l'op�ration est une copie du nom de fichier.
                if (e.Effect == DragDropEffects.Copy)
                {
                    try
                    {
                        lstBxGauche.Items.Clear();
                        foreach (string NomDeFichier in Fichiers)
                        {
                            lstBxGauche.Items.Add(NomDeFichier);
                            lstBxDroite.Items.Add(NomDeFichier);
                        }
                        lstBxDroite.Items.Add(string.Format("-------- {0} fichiers ajout�s --------",Fichiers.Length));
                    }

                    catch (Exception ex)
                    {
                        MessageBox.Show(ex.Message);
                        return;
                    }
                }
            }
        }

        private void lstBxGauche_DragEnter(object sender, DragEventArgs e)
        {
            //Autorise seulement les donn�es de type : fichier 
            if (e.Data.GetDataPresent(DataFormats.FileDrop) == false)
                e.Effect = DragDropEffects.None;
            e.Effect = DragDropEffects.Copy;
        }

        private void lstBxGauche_DragOver(object sender, DragEventArgs e)
        {
            // Si c'est la source est un fichier on autorise le relach� sur le composant
            if (!e.Data.GetDataPresent(DataFormats.FileDrop))
            {
                e.Effect = DragDropEffects.None;
                return;
            }
            e.Effect = DragDropEffects.Copy;
        }
    }
}