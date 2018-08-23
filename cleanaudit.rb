
exit if Object.const_defined?(:Ocra)

def parse_transtime(line)
	if line =~ /^(\d{1,2}:\d\d\s[AP]M)(,|\s)/
		transtime = $1
	end
	transtime
end

def parse_transtype(line)
	if line =~ /(,|\s)(\w+)\sPAYMENT/
		transtype = $2
	end
	transtype
end

def parse_cardtype(line)
	if (line =~ /(VISA|MC|M\/C|MASTERCARD|AMEX|DISC|DISCOVER)\son\s/i ||
	    line =~ /\,(VISA|MC|M\/C|MASTERCARD|AMEX|DISC|DISCOVER)/i ||
	    line =~ /-\s(VISA|MC|M\/C|MASTERCARD|AMEX|DISC|DISCOVER)/i)
		cardtype = $1
	else
		line =~ /PAYMENT\s(.*)\son/i
		cardtype = $1
	end
	cardtype
end

def parse_table(line)
	if line =~ /\son\s(.+?)\s(Chk:)/
		table = $1
	end
	if table.include? ','
		table.sub!(',','')
	end
	table
end

def parse_check(line, transtype)
	if transtype == 'MOVE'
		if line =~ /\sChk:(\d{5,8})\sto\sChk:(\d{5,8})\s/
			check = "#{$1} -> #{$2}"
		end
	else
		if line =~ /\sChk:(\d{5,6})\s/
			check = $1
		end
	end
	check
end

def parse_employee(line)
	if (line =~ /\sChk:\d{5,6}\sby\s(.+)\s-\s/ ||
	    line =~ /PAYMENT,(Mgr:.+Emp:.+)\son\s/ ||
	    line =~ /PAYMENT\s(Mgr:.+Emp:.+)\son\s/)
		employee = $1
	end
	employee
end

def parse_authamt(line, transtype)
	if (transtype == 'APPLY' || transtype == 'MOVE')
		if line =~ /\s-\s,*(\d+\.\d\d)\s/
			authamt = $1
		end
	elsif transtype == 'ADJUST'
		if line =~ /\s-\s,*Amt:\d+\.\d\d\s->\s(\d+\.\d\d)\s/
			authamt = $1
		elsif line =~ /\s-\s,*Amt:(\d+\.\d\d)\s/
			authamt = $1
		end
	elsif transtype == 'DELETE'
		if line =~ /(\s|,)(\d+\.\d\d)\sTip:/
			authamt = $2
		end
	end
	authamt
end

def parse_startip(line)
	if line =~ /Tip:(\d+\.\d\d)\s->\s\d+\.\d\d/
		starttip = $1
	end
	starttip
end

def parse_endtip(line)
	if line =~ /Tip:\d+\.\d\d\s->\s(\d+\.\d\d)/
		endtip = $1
	elsif line =~ /Tip:(\d+\.\d\d)\s/
		endtip = $1
	end
	if endtip == '0.00'
		endtip = ''
	end
	endtip
end

def parse_cardnum(line)
	if line =~ /\sID:(\d{15,16})\s/
		cardnum = $1
	elsif line =~ /Tip:\d+\.\d\d\s(\d{15,16})\sExp:/
		cardnum = $1
	elsif line =~ /\sID:X+\d{4}\s->\s(\d{15,16})\sExp:/
		cardnum = $1	
	else line =~ /\sID:(.*)\sExp:/
		cardnum = $1	
	end
	if (cardnum)
		cardnum = "#{cardnum}_"
	end
	cardnum
end

def parse_expiration(line)
	if line =~ /\sExp:(\d{4})/
		expiration = $1
	end
	expiration
end

def parse_cardmask(line, cardnum)
	if cardnum =~ /(\d{4})\_/
		cardmask = $1
	elsif line =~ /X{11,12}(\d{4})\s/
		cardmask = $1
	end
	cardmask
end




Dir.glob("Audit????.csv") do |audit|
	cleanfile = audit.gsub(/Audit/, "cleanaud")
	cleanaudit = File.new(cleanfile, "w")
	File.open(audit, "r") do |auditlines|
		cleanaudit.puts "TIME,TRANSTYPE,CARDTYPE,TABLE,CHECK,EMPLOYEE,AUTHAMT,STARTTIP,ENDTIP,CARDNUM,EXP,CARDMASK"
		line_number = 0
		shouldREM = 0
		while line = auditlines.gets
			if (line_number == 1 && !(line =~ /\sID:/))
				next
			elsif line_number == 1
				line_number = 2
			end
			if (line =~ /^\d{1,2}:\d\d\s[AP]M.+PAYMENT/ && line_number == 0)
				line_number = 1
			end
			if (line_number == 1)
				txn = line.chomp
			elsif (line_number == 2)
				txn = "#{txn} - #{line}"
				
				transtime = parse_transtime(txn)
				transtype = parse_transtype(txn)
				cardtype = parse_cardtype(txn)
				table = parse_table(txn)
				check = parse_check(txn, transtype)
				employee = parse_employee(txn)
				authamt = parse_authamt(txn, transtype)
				starttip = parse_startip(txn)
				endtip = parse_endtip(txn)
				cardnum = parse_cardnum(txn)
				expiration = parse_expiration(txn).to_s.rjust(4, '0')
				cardmask = parse_cardmask(txn, cardnum)
			
			
				if (transtime && transtype && authamt && cardmask)
					cleanaudit.puts "#{transtime},#{transtype},#{cardtype},#{table},#{check},#{employee},#{authamt},#{starttip},#{endtip},#{cardnum},#{expiration},#{cardmask}"
				else
					if (shouldREM ==0)
						removefile = audit.gsub(/Audit/, "REMOVE")
						removeaudit = File.new(removefile, "w")
						removeaudit.puts "TIME,TRANSTYPE,CARDTYPE,TABLE,CHECK,EMPLOYEE,AUTHAMT,STARTTIP,ENDTIP,CARDNUM,EXP,CARDMASK"
						shouldREM = 1
					end
					removeaudit.puts "#{transtime},#{transtype},#{cardtype},#{table},#{check},#{employee},#{authamt},#{starttip},#{endtip},#{cardnum},#{expiration},#{cardmask}"
					#cleanaudit.puts "#{transtime},#{transtype},ERROR-DELETE,#{table},#{check},#{employee},#{authamt},#{starttip},#{endtip},#{cardnum},#{expiration},#{cardmask}"
					#cleanaudit.puts "ERROR,\"#{txn}\",#{transtime},#{transtype},#{authamt},#{cardmask}"
				end
				
				line_number = 0
			end
		end
	end
	cleanaudit.close
end

	