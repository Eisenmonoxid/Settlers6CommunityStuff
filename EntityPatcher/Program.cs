using System;
using System.Collections.Generic;
using System.IO;
using System.Text;

namespace EntityPatcher
{
    internal class Program
    {
        static void Main(string[] args)
        {
            Console.Title = "Patch Entities";
            Console.ForegroundColor = ConsoleColor.White;
            Console.BackgroundColor = ConsoleColor.Blue;
            Console.Clear();

            Console.WriteLine("Patching xml Files ...");
            String[] Filenames = Directory.GetFiles(Directory.GetCurrentDirectory());
            int Counter = 0;

            foreach (String Filename in Filenames)
            {
                Console.WriteLine("File: " + Filename + "\n");
                String[] Content = File.ReadAllLines(Filename);
                for (int i = 0; i < Content.Length; i++)
                {
                    if (Content[i].Contains("<ShowInTree>false"))
                    {
                        Content[i] = Content[i].Replace("<ShowInTree>false", "<ShowInTree>true");
                    }
                    else if (Content[i].Contains("<Clime>"))
                    {
                        Content[i] = "<Clime>Generic</Clime>";
                    }
                }
                try
                {
                    File.WriteAllLines(Filename, Content);
                }
                catch (Exception)
                {
                    // Just ignore exceptions, do not write anything back to the file
                    continue;
                }
                Counter++;
            }

            Console.WriteLine(Counter.ToString() + " Files Handled!");
            Console.ReadKey();

            Environment.Exit(0);
        }
    }
}