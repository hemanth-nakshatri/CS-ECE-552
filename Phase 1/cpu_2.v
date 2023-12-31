
module cpu(
input clk,
input rst_n,
output hlt,
output [15:0] pc
); 

wire [15:0] curr_pc, next_pc;

//control signals
wire halt;                       //signal to halt PC increment
wire RegDst;                    //select destination register
wire ALUSrc;                    //select ALU input
wire MemRead;                   //enable read from memory
wire MemWrite;                  //enable writing to memory
wire MemtoReg;                  //data to be written into a register
wire RegWrite;                  //write enable for register
wire Lower;                     //select for LLB
wire Higher;                    //select for LHB
wire BEn;                       //branch enable
wire Br;                        //branch type
wire PCS;                       //PCS

wire [2:0] flag, ccc, en;
wire [3:0] rs, rt, rd, destReg; //register file inputs
wire [15:0] instr;              //instruction
wire [15:0] reg1, reg2;         //register file outputs
wire [15:0] aluOut;             //output of ALU
wire [15:0] memData;            //data output from memory
wire [15:0] regData;            //data to write to register
wire [15:0] aluB;               //second input of ALU
wire [15:0] immediate;          //immediate to be passed into ALU
wire [15:0] memAddr;            //memory address
wire [15:0] brAddr;             //address of branch;

//flag_register
flag_register fr(.clk(clk), .rst(~rst_n), .flag_in(flag), .flag_out(ccc), .en(en));
//pc register
pc_reg pcReg(.clk(clk), .rst(~rst_n), .D(next_pc), .WriteEnable(~halt), .q(curr_pc));
//instruction memory
instr_memory iMem(.data_out(instr), .addr(curr_pc), .clk(clk), .rst(~rst_n));
//data memory
data_memory dMem(.data_out(memData), .data_in(reg2), .addr(aluOut), .enable(MemRead), .wr(MemWrite), .clk(clk), .rst(~rst_n));
//register file
RegisterFile rf(.clk(clk), .rst(~rst_n), .SrcReg1(rs), .SrcReg2(rt), .DstReg(destReg), .WriteReg(RegWrite), 
                .DstData(regData), .SrcData1(reg1), .SrcData2(reg2));
//pc control unit
control_pc pcControl(.B(BEn), .ccc(instr[11:9]), .offset(instr[8:0]), .flags(flag), .pc(curr_pc), .target_address(next_pc));
//cpu control unit
CPU_control cpuControl(.opc(instr[15:12]), .halt(halt), .RegDst(RegDst), .ALUSrc(ALUSrc), .MemRead(MemRead), 
                       .MemWrite(MemWrite), .MemtoReg(MemtoReg), .RegWrite(RegWrite), .Lower(Lower), 
                       .Higher(Higher), .BEn(BEn), .Br(Br), .PCS(PCS));
//alu for execution
ALU_16bit aluEx(.ALU_Out(aluOut), .ALU_In1(reg1), .ALU_In2(aluB), .Opcode(instr[15:12]), .Flags(flag), .en(en));

//inputs
assign rs = (Lower | Higher) ? rd : instr[7:4];
assign rt = (MemRead | MemWrite) ? instr[11:8] : instr[3:0];
assign rd = instr[11:8];

//muxes
//if LLB or LHB, then set rs to be rd to allow reading
//select which register to write to
assign destReg = (RegDst) ? rd : rt;
//select immediate
assign immediate = (MemRead | MemWrite) ? {{7{instr[3]}},instr[7:0]} << 1 : {{12{1'b0}},instr[3:0]};
//select input for ALU
assign aluB = (ALUSrc) ? immediate : reg2;
//if LLB or LHB, then write the corresponding byte to reg, if MemtoReg, then write memory output to reg,
//if PCS, then write next_pc value to reg, otherwise default to alu output
assign regData = (Lower) ? (reg1 & 16'hff00) | instr[7:0] : 
                (Higher) ? (reg1 & 16'h00ff) | (instr[7:0] << 8) :
              (MemtoReg) ? memData : (PCS) ? next_pc : aluOut;
//select branch type
assign brAddr = (Br) ? reg1 : {{7{instr[8]}},{instr[8:0]}};

assign hlt = halt;
assign pc = curr_pc;

endmodule
