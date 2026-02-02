using System;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Threading.Tasks;

public class TcpServer
{   
    static void HandleClient(TcpClient client)
    {  
        using (client)
        using (NetworkStream stream = client.GetStream())
        {
            Runspace runspace = RunspaceFactory.CreateRunspace();
            runspace.Open();

            using (PowerShell ps = PowerShell.Create())
            {
                ps.Runspace = runspace;

                byte[] buffer = new byte[1024];

                while (true)
                {
                    int bytesRead = stream.Read(buffer, 0, buffer.Length);
                    if (bytesRead == 0)
                        break;

                    string received = Encoding.UTF8.GetString(buffer, 0, bytesRead);
                    
                    ps.Commands.Clear();
                    ps.AddScript(received);

                    StringBuilder buf = new StringBuilder();

                    foreach (var result in ps.Invoke())
                    {
                        if (result != null)
                        {
                            buf.AppendLine(result.ToString());
                        }
                    }

                    string cwd = runspace.SessionStateProxy.Path.CurrentLocation.Path;
                    buf.AppendLine("\nPS " + cwd);

                    byte[] toSend = Encoding.UTF8.GetBytes(buf.ToString());
                    stream.Write(toSend, 0, toSend.Length);
                }
                
            }
            runspace.Close();
        }
    }

    public static void Main()
    {
        TcpListener listener = new TcpListener(IPAddress.Loopback, 9000);
        listener.Start();

        Console.WriteLine("Listining on port 9000");


        while (true)
        {
            
            TcpClient client = listener.AcceptTcpClient();

            Task.Run(() =>
            {
                HandleClient(client);
            });

            
        }
        
    }
}






