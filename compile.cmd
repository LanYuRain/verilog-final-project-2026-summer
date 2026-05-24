del wave                       
del wave.vcd                   
iverilog -o wave tb_digital_lock.v digital_lock.v
vvp wave                      
pause