import hudson.util.RemotingDiagnostics;

print_ip = 'println InetAddress.localHost.hostAddress';
print_hostname = 'println InetAddress.localHost.canonicalHostName';
var_name_of_shell_command_to_run = """println new ProcessBuilder( 'sh', '-c', 'SHELL COMMAND TO RUN GOES HERE').redirectErrorStream(true).start().text"""

for (slave in hudson.model.Hudson.instance.slaves) {
    println RemotingDiagnostics.executeGroovy(print_hostname, slave.getChannel());
    println RemotingDiagnostics.executeGroovy(print_ip, slave.getChannel());
    println RemotingDiagnostics.executeGroovy(var_name_of_shell_command_to_run, slave.getChannel());
}