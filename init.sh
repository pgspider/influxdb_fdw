influx -import -path=init/init.txt -precision=s
influx -import -path=init/selectfunc.txt -precision=s

influx -import -path=init/others.txt -precision=ns
influx -import -path=init/join.txt -precision=ns
influx -import -path=init/select_having.txt -precision=ns
influx -import -path=init/select.txt -precision=ns
influx -import -path=init/onek.txt -precision=ns
influx -import -path=init/tenk.txt -precision=ns
influx -import -path=init/agg.txt -precision=ns
influx -import -path=init/student.txt -precision=ns
influx -import -path=init/person.txt -precision=ns
influx -import -path=init/streets.txt -precision=ns
influx -import -path=init/emp.txt -precision=ns
influx -import -path=init/stud_emp.txt -precision=ns

influx -import -path=init/init_post.txt -precision=ns
