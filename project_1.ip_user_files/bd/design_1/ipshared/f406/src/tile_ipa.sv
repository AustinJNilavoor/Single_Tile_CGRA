////////////////////////////////////////////////////////////////////////////////
// Company:        Multitherman Laboratory @ DEIS - University of Bologna     //
//                    Viale Risorgimento 2 40136                              //
//                    Bologna - fax 0512093785 -                              //
//                                                                            //
// Engineer:       Satyajit Das - satyajit.das@unibo.it                       //
//                                                                            //
// Additional contributions by:                                               //
//                                                                            //
//                                                                            //
//                                                                            //
// Create Date:    17/05/2016                                                 // 
// Design Name:    CGRA                                                       // 
// Module Name:    tile                                                       //
// Project Name:                                                              //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Tile                                                       //
//                                                                            //
//                                                                            //
// Revision:                                                                  //
// Revision v0.1 - File Created                                               //
//                                                                            //
//                                                                            //
//                                                                            //
//                                                                            //
//                                                                            //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module tile_ipa #(parameter AWIDTH = 4, parameter DWIDTH = 32, parameter INST_AWIDTH = 10, parameter NB_ROWS = 4, parameter NB_COLS = 4, parameter INST_DWIDTH = 21)
   (
    input logic 			   Clk, Reset, DMA_Read_En, Exec_En_Global, Load_Store_Grant_I, Data_Req_Valid_I,
// sbypnm   input logic [(NB_ROWS*NB_COLS)-1 : 0]  PE_Cond_In,
// sbypnm   input logic [DWIDTH-1:0] 	 	   PE_In_N, PE_In_S, PE_In_E, 
    input logic [DWIDTH-1:0]                             PE_In_W,
    input logic [22:0] 			   DMA_Addr_In,
//  sbypnm  input logic [3:0] 			   Tile_Id, 
//  sbypnm  input logic [63:0] 			   DMA_Data_In,
// bypnm   input logic [(NB_ROWS*NB_COLS)- 1 : 0] Stall_In,
    input logic [31:0]         	           Load_Data_I, 
//  sbypnm  input logic [(NB_ROWS*NB_COLS)- 1 : 0] memStall_In,
//  sbypnm  output logic [31:0] 		   Load_Store_Addr_O, Store_Data_O,  
//   sbypnm output logic [31:0] 		   Load_Store_Addr_O,  //sbypnm
// sbypnm   output logic [DWIDTH-1:0]              PE_Out_N, PE_Out_S, PE_Out_E, PE_Out_W,
    output logic 			   PE_Cond_Out, End_Exec_O, Load_Store_Req_O, Load_Store_Data_Req_O, Stall_Out,
    output logic [31:0]			   insCount_Out,
    output logic [31:0]			   cycleCount_Out,
    output logic [31:0]			   memStallCount_Out,
    output logic			   memStall_Out,
    output logic [5:0]         opcode_out,
    output logic [31:0] alu_out,
//    output logic Global_Stall_o,inst_fetch_en_o,
//    output logic [20:0] Inst_Data_reg_o,
//    output logic [20:0] Inst_Data_o,
    output logic [5:0] 		 		   Inst_Addr_o
    );


   logic [DWIDTH-1:0] 			   ALU_In0, ALU_In1,ALU_Out_reg, ALU_Out, PE_In_RF_0, PE_In_RF_1;
   logic [19:0] 	                   PE_In_CRF_0, PE_In_CRF_1;
   logic 				   Exec_En, Clock_Gate_En_O, self_clock_gate_en, Load_Store_Req_Out, Load_Store_Data_Req_Out, Load_Store_Req, Load_Store_Data_Req;
   logic 				   ldstraddr_init;
   logic [4:0] 		 		   Read_Addr_CRF_0, Read_Addr_CRF_1;
   logic [5:0] 		 		   Opcode;
   logic 				   Write_En_RF, Read_En_CRF_1, Read_En_CRF_0;
   logic [2:0] 		 		   Write_Addr_RF;
   logic [20:0] 	 	           Inst_Data_reg;
   logic [20:0] 	 		   Inst_Data;   
   logic [5:0] 		 		   Inst_Addr;
   logic 				   Write_En_IM, Write_En_CRF, ALU_En, Counter_En;
   logic 				   Global_Cond, Global_Stall;
   logic [(NB_ROWS*NB_COLS)-1:0] 	   PE_Cond_In_Reg;
   logic [4:0] 		 		   Count_Nop;
   logic 				   Halt_Reg, gated_clk;
   logic 				   ls_active, end_exec;
   logic [31:0] 			   alu_out_prev, load_data, load_store_addr;
   logic 				   exec;
   integer 				   active, inactive;

   logic 				   sfu_cond_out;
   logic [31:0] 			   sfu_out, alu_out_o;
   logic 				   sfu_en;
   logic 				   jmp_trigger;
   logic 				   jmp_init;
   logic 				   inst_fetch_en;
   logic 				   alu_data_fetch_en;
   logic 				   sfu_data_fetch_en;
   logic 				   ig_en;
   logic [4:0] 				   jmp_index;
   logic [4:0] 				   BA_addr;   
   //by chilanka for hardware loop
   logic [2:0] hloopID;  
   logic [31:0] ins_count; //to display the number of instructions executed
   logic [31:0] jmp_count; //to display the number of jmps executed
   logic [31:0] pe_util; 
   logic [31:0] memStall_count;
   logic [31:0] cycle_count;
   logic 	Global_memStall;


  assign insCount_Out=ins_count;
  assign cycleCount_Out=cycle_count;
  assign memStallCount_Out=memStall_count;
  assign opcode_out=Opcode;
  assign alu_out=alu_out_o;
//  assign Global_Stall_o=Global_Stall;
//  assign inst_fetch_en_o=inst_fetch_en;
//  assign Inst_Data_reg_o=Inst_Data_reg;
//  assign Inst_Data_o=Inst_Data;
  assign Inst_Addr_o=Inst_Addr;
  always_ff @(posedge Clk or negedge Reset)
  begin
   	if(Reset == 1'b0) begin
   		exec <= 0;
   	end else if(Exec_En_Global==1'b1) begin
   		exec <= 1;
   	end else if (End_Exec_O == 1'b1) begin
   		exec <=0;
   	end
  end
   
  always_ff @(posedge Clk or negedge Reset)
  begin
   	  if(Reset == 1'b0) begin
            Load_Store_Req <= '0;
   	    Load_Store_Data_Req<= '0;
   	    load_store_addr <= '0;
   	    ldstraddr_init <= 0;
   	  end else begin
   	    Load_Store_Req <= Load_Store_Req_Out;
   	    Load_Store_Data_Req <= Load_Store_Data_Req_Out;
   	    load_data <= Load_Data_I;
//   	    load_store_addr <= Load_Store_Addr_O;
   	    ldstraddr_init <= Load_Store_Req_Out == 1 ? 1 : 0;
   	  end
  end // always_ff @ (posedge Clk or negedge Reset)

   always_ff @(posedge Clk or negedge Reset)
     begin
   	if(Reset == 1'b0) begin
   	   // ALU_En <= '0;
	   // sfu_en <= '0;
   	   Halt_Reg <= '1;
   	   Load_Store_Req_Out <= '0;
   	   Load_Store_Data_Req_Out <= '0;
   	   end_exec <= 1'b1;
   	   End_Exec_O <= 1'b0;
   	   ALU_Out_reg <= '0 ;
   	   alu_out_prev <= '0;
	end else if (exec==1'b1) begin    
     	   // ALU_En <= (!Inst_Data[5]) & (!Global_Stall);
     	   ALU_Out_reg <=  (Data_Req_Valid_I == '1) ? Load_Data_I : ALU_Out;
     	   alu_out_prev <= (Data_Req_Valid_I == '1) ? Load_Data_I : ALU_Out;

     	   if(Inst_Data[5:0] == 6'b011111) begin
     	      End_Exec_O <= 1'b1;
     	      end_exec <= 1'b0;	     
     	   end
	   if(((Inst_Data[5:0] == 6'b000111) && Clock_Gate_En_O == '1 && Load_Store_Grant_I != '1 && Global_Stall!=1)&&
	      ((inst_fetch_en&&!Inst_Data_reg[5])||(inst_fetch_en&&Inst_Data_reg[5]))) begin  //B_LD
	      	Load_Store_Req_Out <= 1'b1;
	     	 Load_Store_Data_Req_Out <= 1'b1;
	   end else if((Inst_Data[5:0] == 6'b001001   && Clock_Gate_En_O == '1 && Load_Store_Grant_I != '1 && Global_Stall!=1)&&
	      ((inst_fetch_en&&!Inst_Data_reg[5])||(inst_fetch_en&&Inst_Data_reg[5]))) begin // STR
	      	Load_Store_Req_Out <= 1'b1;
	      	Load_Store_Data_Req_Out <= 1'b0;            
	   end else if(Load_Store_Grant_I == '1) begin
	      	Load_Store_Data_Req_Out <= '0;
	      	Load_Store_Req_Out <= '0;
	   end 
	end else begin
	   // ALU_En <= '0;
	   End_Exec_O <= '0;
	end
     end // always_ff @ (posedge Clk or negedge Reset)


   //by chilanka for performance evaluation
   always @(posedge gated_clk or negedge Reset)
        begin
        if(Reset == 1'b0) begin 
            ins_count<=0;
            jmp_count<=0;
	    pe_util<=0;
	    memStall_count<=0;
	    cycle_count<=0;
	    memStall_Out<=0;
        end
        else begin
	  if (exec ==1'b1)
		cycle_count=cycle_count+1;

          if (exec ==1'b1 && (Clock_Gate_En_O == '1) && (Global_Stall != '1)&&(inst_fetch_en) && (Inst_Data[5:0]!=6'b011110) ) 
               ins_count<=ins_count+1; 
          if (exec ==1'b1 && (Clock_Gate_En_O == '1) && (Global_Stall != '1)&&(inst_fetch_en) && ((Inst_Data[5:0] == 6'b010100) || (Inst_Data[5:0]==6'b010011))) 
               jmp_count<=jmp_count+1; 
	  if (exec ==1'b1 && Clock_Gate_En_O == '1 )
	// if (exec ==1'b1 && Clock_Gate_En_O == '1 && Inst_Data[5:0]!=6'b011110)  
               pe_util<=pe_util+1;  
          // if (exec ==1'b1 && Clock_Gate_En_O == '1 && Global_Stall == '1)  
 	//if (((Opcode == 6'h07) ||(Opcode == 6'h09))&&(Load_Store_Grant_I == '0)&&(exec ==1'b1) && (Clock_Gate_En_O == '1) )  //if opcode is load/store but mem access is not granted
	if ((Load_Store_Req_Out == '1)&&(Load_Store_Grant_I == '0)&&(exec ==1'b1) && (Clock_Gate_En_O == '1) )  //mem access is requested but not granted
		memStall_Out<=1;
        else    memStall_Out<=0;
	if (Global_memStall==1)
		memStall_count<= memStall_count+1;     
      
        end
    end

  orcond #(NB_ROWS, NB_COLS) orcond_memStall(
//  sbypnm	.In_Cond(memStall_In),
  	.Out_Cond(Global_memStall)
  	);


/* -----\/----- PEController -----\/----- */

   always_ff @(posedge gated_clk or negedge Reset)
     begin
	   if(Reset == 1'b0) begin
     	   Write_En_IM <='0;
     	   Write_En_CRF <='0;
     	   Inst_Data_reg <='0;
     	   Exec_En <= '0;  
        
     	   //commented by chilanka
     	   //Inst_Addr <= '0;  	   
	   end else if (exec ==1'b1 && (Clock_Gate_En_O == '1)) begin
	     Exec_En <= 1'b1;
	     Write_En_IM <= 1'b0;
	     Write_En_CRF <= 1'b0;  
//	 sbypnm    PE_Cond_In_Reg<= PE_Cond_In;

	     // if ((Global_Stall != '1)) begin
	     if ((Global_Stall != '1)&&(inst_fetch_en)) begin
     	      Inst_Data_reg <= Inst_Data;   
                       
     	      //Inst_Addr <= (Inst_Data[5:0]==6'b011110) ? '0 : 
            //((Inst_Data[5:0]==6'b010100)||((Inst_Data[5:0]==6'b010011) && (Global_Cond==1'b1))) ? Inst_Data[11:6] : 
            //((Inst_Data[5:0]==6'b010011) && (Global_Cond==1'b0)) ? Inst_Data[17:12] : Inst_Addr+1;
     	end
     
	  end else begin
     	   Write_En_IM <= 1'b0;
	       Write_En_CRF <= 1'b0;
        
	 end // else: !if(Exec_En_Global==1'b1

  end // always_ff @

   always@( * ) 
     begin
   	if (exec == 1'b1) begin
//	 sbypnm  PE_Out_N <= ALU_Out_reg;
//	sbypnm   PE_Out_S <= ALU_Out_reg;
//	sbypnm   PE_Out_E <= ALU_Out_reg;
//	sbypnm   PE_Out_W <= ALU_Out_reg;	
	   Opcode <= Inst_Data_reg[5:0];
	   self_clock_gate_en = (Inst_Data[5:0]==6'b011110) ? '1 : '0; 
	   Write_En_RF <= ((Inst_Data_reg[5:0]==6'b000000) || (Inst_Data_reg[5:0]==6'b010011) ||(Inst_Data_reg[5:0]==6'b010100)) ? 1'b0 : 1'b1;
	   Write_Addr_RF <=  Inst_Data_reg[8:6];
	   Read_Addr_CRF_0 <= Inst_Data_reg[14:10];
	   Read_Addr_CRF_1 <= Inst_Data_reg[20:16];
	   Read_En_CRF_0 <= Inst_Data_reg[9];
	   Read_En_CRF_1 <= Inst_Data_reg[15];

//     sbypnm	   ALU_In0 <=  
//    sbypnm 	       (Read_En_CRF_0  == 0) && (Read_Addr_CRF_0 == 5'b01001) ? PE_In_N:
//	sbypnm       (Read_En_CRF_0  == 0) && (Read_Addr_CRF_0 == 5'b01010) ? PE_In_S:
//		sbypnm       (Read_En_CRF_0  == 0) && (Read_Addr_CRF_0 == 5'b01011) ? PE_In_E:
		  ALU_In0 <= (Read_En_CRF_0  == 0) && (Read_Addr_CRF_0 == 5'b01100) ? PE_In_W:
		       (Read_En_CRF_0  == 1) ? PE_In_CRF_0 : PE_In_RF_0;

     	   ALU_In1 <=  
//     sbypnm	       (Read_En_CRF_1  == 0) && (Read_Addr_CRF_1 == 5'b01001) ? PE_In_N:
//		sbypnm       (Read_En_CRF_1  == 0) && (Read_Addr_CRF_1 == 5'b01010) ? PE_In_S:
//		 sbypnm      (Read_En_CRF_1  == 0) && (Read_Addr_CRF_1 == 5'b01011) ? PE_In_E:
		       (Read_En_CRF_1  == 0) && (Read_Addr_CRF_1 == 5'b01100) ? PE_In_W:
		       (Read_En_CRF_1  == 1) ? PE_In_CRF_1 : PE_In_RF_1;

     	   if((Inst_Data[5:0] == 6'b000000 && (Inst_Data[10:6]>5'b00001) && (Global_Stall != '1))&&((inst_fetch_en&&!Inst_Data_reg[5])||!(!inst_fetch_en&&Inst_Data_reg[5]))) begin
     	      Count_Nop <= Inst_Data[10:6] -1;
     	      Counter_En <= 1'b1 ;
     	   end else begin
       	      Counter_En <= '0;
       	      Count_Nop <= '0;
	   end
	   if((((Inst_Data[5:0] == 6'b000111)||(Inst_Data[5:0] == 6'b001001)) && (Global_Stall != '1))) begin  // B_LD || STR
              ig_en <= 1'b1;
              BA_addr <= Inst_Data[14:10];
	   end else begin
              ig_en <= 1'b0;
	   end

	   //commented by chilanka
	   //if (((Inst_Data[5:0] == 6'b010100) && (Global_Stall != '1) && (Clock_Gate_En_O == '1))) begin // JMP
          //    jmp_trigger <= Inst_Data[20];
            //  jmp_index <= Inst_Data[17:13];
	   //end else begin
             // jmp_trigger <= 1'b1;
	   //end   
	   


   	   //Store_Data_O <= ALU_In0;
//       sbypnm    Store_Data_O <= alu_out_o;//by chilanka as a quick fix; need to edit assembly to perform operation in the same tile of store
	   // Load_Store_Addr_O <= (ldstraddr_init == 0 && Load_Store_Req_Out == 1) ? ALU_In1<<2  : load_store_addr;
	   Stall_Out <= Load_Store_Req_O ;

	end else begin
//	sbypnm   PE_Out_N <= '0;
//	sbypnm   PE_Out_S <= '0;
//	sbypnm   PE_Out_E <= '0;
//	sbypnm   PE_Out_W <= '0;	
	   Opcode <= '0;
	   Write_En_RF <= '0;
	   Write_Addr_RF <='0;
	   self_clock_gate_en = '0;
	   Read_Addr_CRF_0 <= '0;
	   Read_Addr_CRF_1 <= '0;
	   Read_En_CRF_0 <= '0;
	   Read_En_CRF_1 <= '0;
//	sbypnm   Store_Data_O <=  '0;
	   //sbypnm Load_Store_Addr_O <= '0;
	   Stall_Out <= 1'b0;
	   ALU_In1 <= '0;
	   ALU_In0 <= '0;
	   ls_active <= '0;
	   Counter_En <= '0;
	   Count_Nop <= '0;
	end // else: !if(Exec_En_Global==1'b1)
     end // always@

   assign Load_Store_Data_Req_O = Load_Store_Data_Req_Out;
   assign Load_Store_Req_O      = Load_Store_Req_Out;

   //Instruction Address Generator + hardware loop by chilanka // hloop.sv
   ins_ag Ins_ag(
      .Clk(gated_clk),
      .Reset(Reset), 
      .exec(exec),    
      .inst_fetch_en(inst_fetch_en),           
      .Global_Cond(Global_Cond), 
      .Global_Stall(Global_Stall), 
      .Clock_Gate_En_O(Clock_Gate_En_O),
      .Inst_Addr_In(Inst_Addr),
      .Inst_Data_In(Inst_Data),
      .loopID_In(hloopID),
      .loopID_Out(hloopID),
      .Inst_Addr_Out(Inst_Addr),    
      .jmp_index(jmp_index),
      .jmp_trigger(jmp_trigger),
      .jmp_init(jmp_init)
     
    );

  scrf scrf_pe(
  	.Clk(Clk),
  	.Reset(Reset),
//  sbypnm	.In_Const(DMA_Data_In),
//  sbypnm	.Write_En((DMA_Addr_In[Tile_Id] == 1'b1) && (DMA_Addr_In[16] == 1) ? DMA_Read_En : 1'b0),
  	.Read_En_CRF_0(Read_En_CRF_0),
  	.Read_Addr_CRF_0(((Inst_Data_reg[5:0] == 6'h07) || (Inst_Data_reg[5:0] == 6'h08) || (Inst_Data_reg[5:0] == 6'h09)) ? {1'b0,Inst_Data[10:6]} :   {1'b0,Read_Addr_CRF_0}),
  	.Read_Data_CRF_0(PE_In_CRF_0),
  	.Read_En_CRF_1(Read_En_CRF_1),
  	.Read_Addr_CRF_1({1'b0,Read_Addr_CRF_1}),
  	.Read_Data_CRF_1(PE_In_CRF_1),
        .Write_Addr(DMA_Addr_In[21:17]),
  	// .index_sel_i(Inst_Data[19:16]), 
  	// .en_seq_i(Inst_Data[19:17]),
//  sbypnm	.address_o(Load_Store_Addr_O),
	.jmp_index(jmp_index),
	.jmp_trigger(jmp_trigger),
	.jmp_init(jmp_init),
	.index_addr(Inst_Data[20:16]),
	.BA_addr(BA_addr),
        .ig_en(ig_en)
	);

  regfile_pe regfile_pe(
  	.Clk(Clk),
  	.Reset(Reset), 
  	.Read_En0(!Read_En_CRF_0), 
  	.Read_En1(!Read_En_CRF_1), 
  	.Write_En(Write_En_RF & (!Global_Stall)),
  	.Read_Addr0(Read_Addr_CRF_0[2:0]), 
  	.Read_Addr1(Read_Addr_CRF_1[2:0]), 
  	.Write_Addr(Write_Addr_RF),
  	.Read_Data0(PE_In_RF_0), 
  	.Read_Data1(PE_In_RF_1), 
  	.Write_Data(ALU_Out)
  	);

  logic sfu_en_i;

  inst_sync inst_sync_pe( 
    //INPUT
    .Clk(Clk),
    .Reset(Reset),
    .opcode(Inst_Data[5:0]),
    .LSreq(Load_Store_Req_Out|| !Clock_Gate_En_O || Global_Stall),
    //OUTPUT
    .inst_fetch_en(inst_fetch_en),
    .alu_data_fetch_en(alu_data_fetch_en),
    .sfu_data_fetch_en(sfu_data_fetch_en),
    .DS_data_fetch_en(),
    .sfu_en(sfu_en_i),
    .DS_en()
    );

  instmem_pe instmem_pe(
  	.Clk(gated_clk),
  	.Reset(Reset),
  	.exec_en(exec),
//  sbypnm	.Write_En((DMA_Addr_In[Tile_Id] == 1'b1) && (DMA_Addr_In[16] == 0) ? DMA_Read_En : 1'b0),
//  sbypnm	.In_Inst(DMA_Data_In),
  	.Inst_Addr(Inst_Addr),
  	.Inst_Data(Inst_Data),
  	.Write_Addr(DMA_Addr_In[22:17])
  	);

// Clock gating with glitch prevention latch
  /*logic Clk_alu;
  logic en_alu;

  always @ (Clk or ((!Inst_Data_reg[5]) & (!Global_Stall)) )
  begin
    if (!Clk) 
    begin 
          en_alu = ((!Inst_Data_reg[5]) & (!Global_Stall));
    end 
  end

  assign Clk_alu = en_alu & Clk;*/

  alu_pe alu_pe(
  	.Clk(Clk),
  	.Reset(Reset),
  	.ALU_En( ((!Inst_Data_reg[5]) & (!Global_Stall)) ),
  	.alu_in_prev(alu_out_prev),
  	.Exec_En_Global(exec),
  	.load_data_i(Load_Data_I),
  	.data_req_valid_i (Data_Req_Valid_I),
  	.ALU_In0(ALU_In0),
  	.ALU_In1(ALU_In1),
  	.Opcode(Opcode),
  	.ALU_Out(alu_out_o),
  	.ALU_Cond(PE_Cond_Out)
  	);

// Clock gating with glitch prevention latch
  logic Clk_sfu;
  // logic en_sfu;

  /*always @ (Clk or (sfu_en_i || sfu_data_fetch_en) )
  begin
    if (!Clk) 
    begin 
          en_sfu = (sfu_en_i || sfu_data_fetch_en);
    end 
  end

  assign Clk_sfu = en_sfu & Clk;*/

  //C8T28SOI_LRP_CNHLSX9_P0 SFU_latch ( .CP(Clk), .E(sfu_en_i), .TE(sfu_data_fetch_en), .Q(Clk_sfu) );

  fpu_top fpu_top_ipa(
  //Clock and reset
   .Clk(Clk_sfu),
   .Reset(Reset),
   .Enable_SI(((Inst_Data_reg[5]) & (!Global_Stall))||(((Inst_Data_reg[5:0]==6'h19)||(Inst_Data_reg[5:0]==6'h1A)) & (!Global_Stall))),

   .Exec_En_Global(exec),   //
   .data_req_valid_i(Data_Req_Valid_I),   //

   //Input Operands
   .load_data_i(Load_Data_I),    //
   .fpu_in_prev(),    //
   .Operand_a_DI(ALU_In0),
   .Operand_b_DI(ALU_In1),
   .OP_SI(Opcode),        // opcode 6-bits

   //OUTPUT
   // output logic               SFU_Cond,
   .Result_DO(sfu_out),

   .result_valid_o(), // result is valid
   .fpu_busy()
   );


  orcond #(NB_ROWS, NB_COLS) orcond_pe(
//  bypnm	.In_Cond(PE_Cond_In),
  	.Out_Cond(Global_Cond)
  	);
  orcond #(NB_ROWS, NB_COLS) orstall_pe(
//  sbypnm	.In_Cond(Stall_In),
  	.Out_Cond(Global_Stall)
  	);


  counter_pe counter_pe(
  	.Clk(Clk),
  	.Reset(Reset),
  	.Counter_En(Counter_En),
  	.Global_Stall_I(Global_Stall),
  	.Clock_Gate_En_O(Clock_Gate_En_O),
  	.Data_In(Count_Nop)
  	);


  cgra_clock_gating counter_gate_pe(
  	.clk_i(Clk),
  	.en_i((!Global_Stall) || Clock_Gate_En_O),
  	.test_en_i(1'b0),
  	.clk_o(gated_clk)   
  	); 

  assign ALU_Out = (sfu_data_fetch_en) ? sfu_out : alu_out_o;

endmodule
