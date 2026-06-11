connect
after 200
# Reset and halt ARM cleanly
catch { targets -set -nocase -filter {name =~ "ARM*#0"} }
catch { rst -processor }
after 500
catch { stop }
after 200
puts "ARM reset+halted"
exit 0
