from myhdl import *
from random import randrange
 
##########################################
def gensig(cnt):
    return [Signal(bool(0)) for i in range(cnt)]
##########################################
def RAM(dout, din, addr, we, clk, wsize=8,nwords=16):
  mem = [Signal(intbv(0)[wsize:]) for i in range(nwords)]
  @always(clk.posedge)
  def write():
    if we:
      mem[int(addr)].next = din
  @always_comb
  def read():
    dout.next = mem[int(addr)]
  return write, read
##########################################
def ROM(dout, addr, CONTENT):
    @always_comb
    def read():
        dout.next = CONTENT[int(addr)]
    return read
##########################################
INS_ROM_CONTENT = ( 0x00888888,
                    0x00888888 )
##########################################p
def tpu_decoder(opcode,fmt,aluop,immed):
  zed = 0x00000000
  data_24 = opcode[24:0]
  data_20 = concat(opcode[20:0],zed[4:0])
  data_16 = concat(opcode[24:8],zed[8:0])
  data_12 = concat(opcode[24:12],zed[12:0])
  fmt = opcode[32:28]
  aluop = opcode[28:24]
  immed = data_24
##########################################
def tweak_registers(douta,doutb,din,addra,addrb, we, clk, wsize=8,nwords=16):
  mem = [Signal(intbv(0)[wsize:]) for i in range(nwords)]
  @always(clk.posedge)
  def writer():
    if we:
      mem[int(addra)].next = din
  @always_comb
  def reader():
    douta.next = mem[int(addra)]
    doutb.next = mem[int(addrb)]
  return writer, reader
##########################################
def tweak_alu( opcode, arga, argb, result ):
  @always_comb
  def muxer():
    if opcode==0:
      result.next = 0
    elif opcode==1:
      result.next = (arga+argb)
    elif opcode==2:
      result.next = (arga-argb)
    elif opcode==3:
      result.next = (arga and argb)
    elif opcode==4:
      result.next = (arga or argb)
    elif opcode==5:
      result.next = (arga ^ argb)
    elif opcode==6:
      result.next = (arga << argb)
    elif opcode==7:
      result.next = (arga >> argb)
  return muxer
########################################## 
def test_t1(): 
  clk = gensig(1)[0]
  #q, d, clk = gensig(3)
  #dff_inst = dff(q, d, clk)
  @always(delay(10))
  def clkgen():
    clk.next = not clk
  #@always(clk.negedge)
  #def stimulus():
  #    d.next = randrange(2)
  #return dff_inst, clkgen, stimulus
  return clkgen  
##########################################
def simulate(timesteps):
    tb = traceSignals(test_t1)
    sim = Simulation(tb)
    sim.run(timesteps)
##########################################
def convert():
    clk = gensig(1)[0]
    #q, d, clk = [Signal(bool(0)) for i in range(3)]
    #toVerilog(clk)
    #toVHDL(dff,q,d,clk)
    #regs = register(16)
    #toVerilog(register,regs)
    return None
##########################################
simulate(2000)
convert()