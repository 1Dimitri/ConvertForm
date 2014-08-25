using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Text;
using System.Windows.Forms;
using System.Xml.Serialization;
using System.IO;

namespace Test1
{
    [Serializable]
    public partial class FrmTest1 : Form
    {
        public FrmTest1()
        {
            InitializeComponent();
        }

        private void button1_Click(object sender, EventArgs e)
        {
            // Insert code to set properties and fields of the object.
            XmlSerializer mySerializer = new  XmlSerializer(typeof(FrmTest1));
            // To write to a file, create a StreamWriter object.
            StreamWriter myWriter = new StreamWriter("myFileName.xml");
            mySerializer.Serialize(myWriter, this);
            myWriter.Close();

        }

        private void dataGridView1_CellContentClick(object sender, DataGridViewCellEventArgs e)
        {

        }

        private void contextMenuStrip1_Opening(object sender, CancelEventArgs e)
        {

        }

        private void listBox1_SelectedIndexChanged(object sender, EventArgs e)
        {

        }

        private void listBox1_KeyDown(object sender, KeyEventArgs e)
        {
            //On traite l'�venement clavier si la liste est vide et la touche 'Delete' press�e.
            if ((listBox1.Items.Count > 0) & (e.KeyCode == Keys.Delete))
            {
                int index=listBox1.SelectedIndex;
                 //L'el�ment s�lectionn� est-il le dernier ?
                if (index == listBox1.Items.Count - 1)
                  //Dans ce cas on se place sur l'el�ment pr�c�dent
                 { index--; }
                // else l'index ne change pas et pointera bien sur le suivant
               
                listBox1.Items.Remove(listBox1.SelectedItem);
                 //On se place sur l'�l�ment s�lectionn� que si la liste contient au moins un �l�ment 
                if (listBox1.Items.Count> 0)
                { listBox1.SelectedIndex = index; }
            }
        }
    }
}