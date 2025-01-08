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
// Module Name:    constantregfile                                            //
// Project Name:                                                              //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Constant register file                                     //
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
module scrf #(parameter READ_AWIDTH = 6, parameter WRITE_AWIDTH = 5, parameter WRITE_DWIDTH = 64, parameter READ_DWIDTH = 20)
	(
		input logic 		   			Clk, Reset, Read_En_CRF_0, Read_En_CRF_1, Write_En,
		input logic [READ_AWIDTH-1:0] 			Read_Addr_CRF_0, Read_Addr_CRF_1,
		input logic [WRITE_DWIDTH-1:0] 			In_Const,
		input logic [WRITE_AWIDTH-1:0] 			Write_Addr,
		input logic [4:0] 				jmp_index,
		input logic 					jmp_trigger,
		input logic 					jmp_init,
		input logic [4:0] 				index_addr,
		input logic [4:0] 				BA_addr,
		input logic					ig_en,
		output logic [READ_DWIDTH-1:0] 			Read_Data_CRF_0, Read_Data_CRF_1, 
		output logic [31:0] 	   			address_o
		);
	localparam 					Num_Regs = 32;
	integer 			   		i;
	//[19:0]  changed to [23:0] to make CRF (32 x 24-bit)	
	logic [Num_Regs-1:0][23:0] 	   		Mem_Content = '{ 
                    24'b000000000000000001100001,
                    24'b000000000000000001100010,
                    24'b000000000000000000000000,
                    24'b000010000000000000000000,
                    24'b000000000000010000000000,
                    24'b000010000000010000000000,
                    24'b000000011001000010100100,
                    24'b000000000000000000000000,
                    24'b000000000000000000000010,
                    24'b000000000000000000000001,
                    24'b0,
                    24'b0,
                    24'b0,
                    24'b0,
                    24'b0,
                    24'b0,
                    24'b0,
                    24'b0,
                    24'b0,
                    24'b0,
                    24'b0,
                    24'b0,
                    24'b0,
                    24'b0,
                    24'b0,
                    24'b0,
                    24'b0,
                    24'b0,
                    24'b0,
                    24'b0,
                    24'b0,
                    24'b0
                    
                    
                };  // forms the CRF
	logic [19:0] 					BA;
	logic [19:0] 					index;
	
	logic [23:0] 					index1;
	logic [23:0] 					index2;
	logic [23:0] 					index3;
	logic [23:0] 					index4;

	logic [9:0] 					IG1_start_i;
	logic [9:0] 					IG2_start_i;
	logic [9:0] 					IG3_start_i;
	logic [9:0] 					IG4_start_i;
	logic [10:0] 					update_lv;

	logic [7:0][11:0]				index_mem; //keeps track of loop varibale vlaues; initaited with start value from CRF(Mem_Content)
	logic [2:0]					updated_start_addr;
	logic [2:0]					updated_start_addr_i;

	logic [10:0]					index1_agu;
	logic [10:0]					index2_agu;
	logic [31:0]					address;
	logic [4:0]					jmp_index_prev;
	logic [31:0]					address_temp;//chilanka
        //24-bit loop val data: bit 23 - scalar/varfalg, 22:14 -loop cal start, 13:5 - loop val end value, 4:0 - loop val step
	logic [8:0]					nbCol;
	logic [8:0]					loopValEnd_ag;
	logic [8:0]					loopValStart_ag;
	logic [8:0]					loopValEnd;
	logic [8:0]					loopValStart;
	logic [4:0]					loopValStep;
	always_ff @(posedge Clk or negedge Reset) begin
		if(Reset == 1'b0) begin
  			//address_temp<='0;//chilanka;
			address_o<='0;//chilanka----
                        jmp_index_prev<='0;//chilanka
			updated_start_addr<='0;//chilanka
			for(i=0; i<Num_Regs; i++) begin
				Mem_Content[i] <= '0;
			end
			for(i=0; i<8; i++) begin
				index_mem[i] <= 12'b0;
			end
			// for(i=0; i<8; i++) begin
			// 	index_mem[i] <= {Mem_Content[i][19:9],1'b0}; // initialise index_mem with first 8 lines of CRF
			// end
		end else if(Write_En) begin
			address_o<='0;//chilanka---
                        jmp_index_prev<='0;//chilanka
			updated_start_addr<='0;//chilanka

                        for(i=0; i<Num_Regs; i++) begin//chilanka
                             if(i!=Write_Addr && i!=Write_Addr+1 && i!=Write_Addr+2)
				Mem_Content[i] <= Mem_Content[i] ;
			end
			/*Mem_Content[Write_Addr] <= In_Const[63:44];
			Mem_Content[Write_Addr+1] <= In_Const[43:24];
			Mem_Content[Write_Addr+2] <= In_Const[23:4];*/
			Mem_Content[Write_Addr] <= In_Const[63:40];
			Mem_Content[Write_Addr+1] <= In_Const[39:16];//0:16 filled with zeros from assembler(convertbytes.cpp)


			for(i=0; i<8; i++) begin
				//commented on 07/06/2023
				//index_mem[i] <= {Mem_Content[i][19:9],1'b0}; // initialise index_mem with first 8 lines of CRF; each entry being the start value of (loop) variables
				index_mem[i] <= {Mem_Content[i][23],1'b0,Mem_Content[i][22:14],1'b0}; // initialise index_mem with first 8 lines of CRF ; each entry being the start 					//value of (loop) variables; index_mem structure-> 11:digit/varFlag, 10..1:value of loop variable, 0:dirtyBit
			end
	

		end else if (jmp_trigger == 1'b0) begin	
                        for(i=0; i<Num_Regs; i++) begin//chilanka
				Mem_Content[i] <= Mem_Content[i] ;
			end
                        for(i=0; i<8; i++) begin //chilanka
				index_mem[i] <= index_mem[i];
			end		
			updated_start_addr <= updated_start_addr_i; // store the address of updated lv **			
			// index_mem[updated_start_addr][10:0] <= update_lv;
			index_mem[updated_start_addr_i][10:0] <= update_lv;
			index_mem[updated_start_addr_i][11] <=	index_mem[updated_start_addr_i][11];//chilanka
			jmp_index_prev <= jmp_index;
			//address_o<='0;//chilanka---
			address_o<=address;//chilanka---
			//address_temp<='0;//chilanka 02/06/2023
			//address_temp<=address;//chilanka
		end else if (ig_en) begin
                        for(i=0; i<Num_Regs; i++) begin//chilanka
				Mem_Content[i] <= Mem_Content[i] ;
			end
			for(i=0; i<8; i++) begin //chilanka
				index_mem[i] <= index_mem[i];
			end
                        jmp_index_prev<='0;//chilanka
			updated_start_addr<='0;//chilanka	
			address_o <= address;
			//address_temp <= address;//chilanka
			// index_mem[updated_start_addr][10:0] <= update_lv;		
		end else begin
                        for(i=0; i<Num_Regs; i++) begin//chilanka
				Mem_Content[i] <= Mem_Content[i] ;
			end
			for(i=0; i<8; i++) begin //chilanka
				index_mem[i] <= index_mem[i];
			end
                        jmp_index_prev<='0;//chilanka
			updated_start_addr<='0;//chilanka
			//address_temp <= address;//chilanka
			address_o <= address;
			// for(i=0; i<8; i++) begin
			// 	index_mem[i] <= {Mem_Content[i][19:9],1'b0}; // initialise index_mem with first 8 lines of CRF
			// end
		end
	end

	always_comb begin
		//CRF
		if(Read_En_CRF_0 == 1'b1) begin
			Read_Data_CRF_0 <= Mem_Content[Read_Addr_CRF_0][19:0];			
        	end else begin
        		Read_Data_CRF_0 <= '0;
        	end

        	if(Read_En_CRF_1 == 1'b1) begin
        		Read_Data_CRF_1 <= Mem_Content[Read_Addr_CRF_1][19:0];
      		end else begin
      			Read_Data_CRF_1 <= '0;
      		end

   	end // always_comb

    // address generation
    always_comb begin
   	if (ig_en) begin
   		index = Mem_Content[index_addr][19:0]; // crf addresses of loop variables from load/store ins
   		index1 = Mem_Content[index[19:15]]; // i's CRF address and i_incr
   		index2 = Mem_Content[index[14:10]];
   		index3 = Mem_Content[index[9:5]];// j's CRF address and j_incr
   		index4 = Mem_Content[index[4:0]];
             
                //index1[19]=1 => a loop var(OR present in CRF) //i_v31 0 1 0 j_v37 0 1 0 - style 
                //index_mem[index1[12:10]][11] =0 => value of loop variable is a scalar. Otherwise it is a variable but this is not handled as hardware loop does not support dynamic 			//loop count
                IG1_start_i = (index1[19]) ? (index_mem[index1[12:10]][11]) ? index_mem[index_mem[index1[12:10]][3:1]][10:1] : index_mem[index1[12:10]][10:1] : {1'b0,index1[18:10]} ;
   		IG2_start_i = (index2[19]) ? (index_mem[index2[12:10]][11]) ? index_mem[index_mem[index2[12:10]][3:1]][10:1] : index_mem[index2[12:10]][10:1] : {1'b0,index2[18:10]} ;
   		IG3_start_i = (index3[19]) ? (index_mem[index3[12:10]][11]) ? index_mem[index_mem[index3[12:10]][3:1]][10:1] : index_mem[index3[12:10]][10:1] : {1'b0,index3[18:10]} ;
   		IG4_start_i = (index4[19]) ? (index_mem[index4[12:10]][11]) ? index_mem[index_mem[index4[12:10]][3:1]][10:1] : index_mem[index4[12:10]][10:1] : {1'b0,index4[18:10]} ;
		
   		// IG1_const_i = (index1[19]) ? (index_mem[index1[12:10]][11]) ? index_mem[index_mem[index1[12:10]][3:1]][10:1] : index_mem[index1[12:10]][10:1] : {1'b0,index1[18:10]} ;
		//index1[9:0] is the increment to the loop variable in index1[12:10] 
   		index1_agu = (IG1_start_i + index1[9:0]) * (IG2_start_i + index2[9:0]); //mostly IG2_start_i and index2[9:0] will be 1 and 0
   		index2_agu = (IG3_start_i + index3[9:0]) * (IG4_start_i + index4[9:0]);//mostly IG4_start_i and index4[9:0] will be 1 and 0

   		BA = Mem_Content[BA_addr][19:0];
                loopValStart_ag=Mem_Content[index3[12:10]][22:14];
                loopValEnd_ag=Mem_Content[index3[12:10]][13:5];
		if(loopValEnd_ag>loopValStart_ag)
			nbCol=loopValEnd_ag-loopValStart_ag+1;
		else	nbCol=loopValStart_ag-loopValEnd_ag+1;
		
   		//address = (((index1_agu + index2_agu)<<2) + Mem_Content[BA_addr]); //BA+ 4* (i+i_incr + j+j_incr)
		address = (((index1_agu*nbCol + index2_agu)<<2) + BA);//BA+ 4*((i+i_incr)*nbCol+(j+j_incr))
   	end else begin
   		//address = address_temp;//chilanka
		address = address_o;
		index = '0;//chilanka
   		index1 = '0;//chilanka
   		index2 = '0;//chilanka
   		index3 = '0;//chilanka
   		index4 = '0;//chilanka
   		IG1_start_i = '0;//chilanka
   		IG2_start_i = '0;//chilanka
   		IG3_start_i = '0;//chilanka
   		IG4_start_i = '0;//chilanka

   		index1_agu = '0;//chilanka
   		index2_agu = '0;//chilanka		
   	end
	

   	if (jmp_trigger == 1'b0) begin
              
	   	if (index_mem[jmp_index[2:0]][11]==1'b0) begin // 0 = constant
                        loopValStart=Mem_Content[jmp_index[2:0]][22:14];
                        loopValEnd=Mem_Content[jmp_index[2:0]][13:5];
                        loopValStep=Mem_Content[jmp_index[2:0]][4:0];

	   		//if ((index_mem[jmp_index[2:0]][0]==1'b1)&&(jmp_index_prev==jmp_index)) begin // loop iteration
			//if ((index_mem[jmp_index[2:0]][0]==1'b1)) begin // loop iteration
			if (jmp_init == 1'b1) begin // loop iteration

				// loop (0)increment or (1)decrement and send this value to AGU
	   			/*update_lv = (Mem_Content[jmp_index][0]) ? {(index_mem[jmp_index[2:0]][10:1] - {2'b0,Mem_Content[jmp_index][8:1]}),1'b1} 
	   								: {(index_mem[jmp_index[2:0]][10:1] + {2'b0,Mem_Content[jmp_index][8:1]}),1'b1};*/
				update_lv = (loopValStart>loopValEnd) ? {(index_mem[jmp_index[2:0]][10:1] - {5'b0,loopValStep}),1'b1} 
	   								: {(index_mem[jmp_index[2:0]][10:1] + {5'b0,loopValStep}),1'b1};
	   			updated_start_addr_i = jmp_index[2:0];

	   		/*end else if ((index_mem[jmp_index[2:0]][0]==1'b1)&&(jmp_index_prev!=jmp_index)) begin // already updated, skip

				update_lv = index_mem[updated_start_addr][10:0];
   				updated_start_addr_i = updated_start_addr;	 */ 		
		   		
	   		end else begin // loop enter // loop initialization
	   			//update_lv = (Mem_Content[jmp_index][0]) ? {(index_mem[jmp_index[2:0]][10:1]),1'b1} : {(index_mem[jmp_index[2:0]][10:1]),1'b1};
				update_lv = {1'b0,(loopValStart),1'b1}; //initialize the variable with start value
 				updated_start_addr_i = jmp_index[2:0];
   			end
	   		
   		end else begin // 1 = variable ===> TO DO ....Not modified as Hardware Loop does not support Dynamic Loop count
   			if ((index_mem[index_mem[jmp_index[2:0]][3:1]][0]==1'b1)&&(jmp_index_prev==jmp_index)) begin // loop iteration
 
   				// loop (0)increment or (1)decrement and send this value to AGU
	   			update_lv = (Mem_Content[jmp_index][0]) ? {(index_mem[index_mem[jmp_index[2:0]][3:1]][10:1] - {2'b0,Mem_Content[jmp_index][8:1]}),1'b1} 
	   								: {(index_mem[index_mem[jmp_index[2:0]][3:1]][10:1] + {2'b0,Mem_Content	[jmp_index][8:1]}),1'b1};
	   			updated_start_addr_i = index_mem[jmp_index[2:0]][3:1];

	   		end else if ((index_mem[index_mem[jmp_index[2:0]][3:1]][0]==1'b1)&&(jmp_index_prev!=jmp_index)) begin // already updated, skip

				update_lv = index_mem[updated_start_addr][10:0];
   				updated_start_addr_i = updated_start_addr;

	   		end else begin // loop enter
	   			update_lv = (Mem_Content[jmp_index][0]) ? {(index_mem[index_mem[jmp_index[2:0]][3:1]][10:1]),1'b1}
									: {(index_mem[index_mem[jmp_index[2:0]][3:1]][10:1]),1'b1};
   				updated_start_addr_i = index_mem[jmp_index[2:0]][3:1];
   			end
   		end
   	end else begin
   		update_lv = index_mem[updated_start_addr][10:0];
   		updated_start_addr_i = updated_start_addr;
   	end

   	//  else begin
   	// end
   end // always_comb

   // assign loop_end = (updated_start_addr_i!=updated_start_addr) ? 1'b1 : 1'b0 ;


  /* agu agu (
	//INPUT
		.index_0(index1_agu),
		.index_1(index2_agu),
		.base_adr(BA),
	//OUTPUT
		.address(address)
		); */

   // assign address_o = address;

endmodule // constantregfile



