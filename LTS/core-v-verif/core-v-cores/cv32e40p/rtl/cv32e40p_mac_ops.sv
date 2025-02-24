import cv32e40p_pkg::*;
//(*DONT_TOUCH = "TURE"*) 
module cv32e40p_mac_ops
(
	input logic						 clk,
	input logic						 rst_n,
	input logic						 enable_i,
	input logic [MAC_OP_WIDTH-1:0]   operator_i,
	input logic [31:0]				 operand_i1,
	input logic [31:0]				 operand_i2,
	input logic				         ex_ready_i,

	input logic [31:0]				 weight_data_cnt,     

	// conv cal data modify
	input logic [31:0]				 active_data_cnt,
	input logic	[31:0]				 wb_data_cnt,
	
	input logic [31:0]				 mem_rdata,

	output logic [31:0]				 mem_wdata,

	output logic 					 wb23_active,       //WB23
	output logic					 wb_finish,         //finish signal


	output logic					 weight_active_o,	//load_weight
    output logic                     active_active_o, 	//load_active

	output logic					 ready_o,
	output logic [2:0]				 mac_flag,
	output logic  					 accum_mode_o

);

//SET MODE
enum logic [2:0] {
	IDLE_MODE,
	SET_MODE,
	FINISH_MODE
} MODE_CS, MODE_NS; 

//GET WEIGHT DATA
enum logic [2:0] {
	IDLE_WEIGHT_DATE,
	GET_WEIGHT_DATA,
	CONFIG_WEIGHT_DATA,
	FINISH_WEIGHT_DATA
}LOAD_WEIGHT_DATA_CS, LOAD_WEIGHT_DATA_NS;


enum logic [2:0] { 
	IDLE_CAL,
	GET_ACTIVE_DATE,
	CONFIG_ACTIVE_DATA,
	CAL_1,
	FINISH_CAL
} CAL_CS, CAL_NS;

enum logic {IDLE_WB, WB23_WDATA} WB23_CS, WB23_NS;


//=================================================================//
//========================= SET MODE REGISTER =====================//
//=================================================================//

logic [4:0]PCM_COUNT ;
logic REUSE_MODE     ;
logic ACCUM_MODE	 ;
logic [2:0]SLICE_MODE;


logic	mode_ready ;
logic	mode_active;
logic	mode_finish;

logic	accum_mode ;

assign accum_mode_o = accum_mode;

//=================================================================//
//======================= LOAD WEIGHT REGISTER ====================//
//=================================================================//
logic [31:0] weight_data [1:0];
logic [15:0] weight_data_splite [3:0];

logic weight_ready  ;
logic weight_active ;
logic weight_get_data ;
logic weight_finish ;

//=================================================================//
//========================== CAL REGISTER =========================//
//=================================================================//
logic [31:0] active_data [1:0];
logic [15:0] active_data_splite [3:0];

logic active_ready  ;
logic active_active ;
logic active_get_data ;
logic active_finish ;



//=================================================================//
//========================== WB REGISTER =========================//
//=================================================================//
logic wb23_ready ;

//=================================================================//
//========================== RESULT REGISTER ======================//
//=================================================================//
logic [31:0] result_data_ACC1[3:0] ;
logic [31:0] result_data_ACC2;

//=================================================================//
//========================== OTHER REGISTER ======================//
//=================================================================//
logic [2:0] max_weight = 'd2;

logic wb23_flag ;
logic weight_flag ;
logic cal_flag ;
// logic mode_flag ;


assign wb_finish = WB23_CS ^ wb23_active;
assign mac_flag = {weight_flag , cal_flag , wb23_flag } ;
// assign ready_o = con_ready & con_core_ready & wb23_ready    ;
assign ready_o = mode_ready & weight_ready & active_ready & wb23_ready;

assign weight_active_o = weight_active ;
assign active_active_o = active_active ;

  // parameter WEIGHT_OP = 4'b0011   ;   3
  // parameter MODE_OP = 4'b0001 ;   1
  // parameter WB23_OP = 4'b0010 ;   2
  // parameter CAL_OP = 4'b0100 ;    4

assign wb23_flag = (operator_i == WB23_OP) && enable_i;
assign weight_flag = (operator_i == WEIGHT_OP) && enable_i ;
assign mode_flag = (operator_i == MODE_OP) && enable_i;
assign cal_flag = (operator_i == CAL_OP) && enable_i;


//demo: load 2 32bits data for 4 16bits from mem, and doing cal


always_ff@(posedge clk, negedge rst_n) begin
	if(~rst_n) begin
		active_data[0] <= 'd0 ;
		active_data[1] <= 'd0 ;
	end
	else begin
		if(active_get_data) begin
			active_data[active_data_cnt - 1] <= mem_rdata;
		end    
	end 
end


//=================================================================//
//========================= GET WEIGHT DATA =======================//
//=================================================================//

//Load 2 32bits is 4 16bits in register
always_ff@(posedge clk, negedge rst_n) begin
	if(~rst_n) begin
		weight_data[0] <= 'd0 ;
		weight_data[1] <= 'd0 ;
	end
	else begin
		if(weight_get_data) begin
			weight_data[weight_data_cnt-1] <= mem_rdata;
		end
	end
end	

//Load weight data
always_ff@(posedge clk, negedge rst_n) begin
	if(~rst_n) begin
		LOAD_WEIGHT_DATA_CS <= IDLE_WEIGHT_DATE;
	end else begin
		LOAD_WEIGHT_DATA_CS <= LOAD_WEIGHT_DATA_NS	;
	end
end	

always_comb begin
	LOAD_WEIGHT_DATA_NS	= LOAD_WEIGHT_DATA_CS	;
	case (LOAD_WEIGHT_DATA_CS)
	IDLE_WEIGHT_DATE: begin
		if(operator_i == WEIGHT_OP && enable_i) begin
			LOAD_WEIGHT_DATA_NS = GET_WEIGHT_DATA;
		end
	end

	GET_WEIGHT_DATA: begin
		if(weight_data_cnt != max_weight) begin
			LOAD_WEIGHT_DATA_NS = GET_WEIGHT_DATA;
		end else begin
			LOAD_WEIGHT_DATA_NS = CONFIG_WEIGHT_DATA;
		end
	end

	CONFIG_WEIGHT_DATA: begin
		LOAD_WEIGHT_DATA_NS = FINISH_WEIGHT_DATA;
	end

	FINISH_WEIGHT_DATA: begin
		if(ex_ready_i)
			LOAD_WEIGHT_DATA_NS = IDLE_WEIGHT_DATE;
	end

	default: begin
		LOAD_WEIGHT_DATA_NS = IDLE_WEIGHT_DATE;
	end 
	endcase
end

always_comb begin
	weight_ready 	= 1'b0;
	weight_active 	= 1'b1;
	weight_get_data = 1'b0;
	weight_finish 	= 1'b0;

	case (LOAD_WEIGHT_DATA_CS)
	IDLE_WEIGHT_DATE: begin
		weight_ready 	= 1'b1;
		weight_active 	= 1'b0;
		weight_get_data = 1'b0;
		weight_finish 	= 1'b0;
	end

	GET_WEIGHT_DATA: begin
		weight_ready 	= 1'b0;
		weight_active 	= 1'b1;
		weight_get_data = 1'b1;
		weight_finish 	= 1'b0;
	end
	CONFIG_WEIGHT_DATA: begin
		weight_ready 	= 1'b0;
		weight_active 	= 1'b1;
		weight_get_data = 1'b0;
		weight_finish 	= 1'b0;

		weight_data_splite[0] = weight_data[0][15:0];
		weight_data_splite[1] = weight_data[0][31:16];
		weight_data_splite[2] = weight_data[1][15:0];
		weight_data_splite[3] = weight_data[1][31:16];

		$display("weight_data_splite[0] = %h", weight_data_splite[0]);
		$display("weight_data_splite[1] = %h", weight_data_splite[1]);
		$display("weight_data_splite[2] = %h", weight_data_splite[2]);
		$display("weight_data_splite[3] = %h", weight_data_splite[3]);

	end

	FINISH_WEIGHT_DATA: begin
		weight_ready 	= 1'b1;
		weight_active 	= 1'b0;
		weight_get_data = 1'b0;
		weight_finish 	= 1'b1;
	end

	default: ;
	endcase

end

//=================================================================//
//============================== SET MODE =========================//
//=================================================================//
always_ff @(posedge clk, negedge rst_n) begin
    if(~rst_n) begin
        MODE_CS <= IDLE_MODE;
    end
    else begin
        MODE_CS <= MODE_NS;
    end 
end

always_comb begin
	MODE_NS = MODE_CS;
	case (MODE_CS)
		IDLE_MODE: begin
			if(operator_i == MODE_OP && enable_i) begin
				PCM_COUNT = operand_i2[4:0];
				REUSE_MODE = operand_i2[5];		// 根据REUSE_MODE来判断是否为重用模式
				ACCUM_MODE = operand_i2[6];		// 根据ACCUM_MODE来判断是否为累加模式
				SLICE_MODE = operand_i2[9:7];
				if(ACCUM_MODE) begin
					accum_mode = 1'b1;
				end else begin
					accum_mode = 1'b0;
				end

				MODE_NS = SET_MODE;
			end
			
		end
		SET_MODE: begin
			MODE_NS = FINISH_MODE;			
		end
		FINISH_MODE: begin
			if(ex_ready_i)
				MODE_NS = IDLE_MODE;
		end
		default: MODE_NS = IDLE_MODE;
	endcase
end

always_comb begin

	mode_ready = 1'b0;
	mode_active = 1'b1;
	mode_finish = 1'b0;

	case (MODE_CS)
		IDLE_MODE : begin
			mode_ready = 1'b1;
			mode_active = 1'b0;
			mode_finish = 1'b0;	
		end 
		SET_MODE: begin
			mode_ready = 1'b0;
			mode_active = 1'b1;
			mode_finish = 1'b0;
		end
		FINISH_MODE: begin
			mode_ready = 1'b1;
			mode_active = 1'b0;
			mode_finish = 1'b1;
		end
		default: ;
	endcase

end

//=================================================================//
//========================= LAOD AND  CAL DATA ====================//
//=================================================================//

//Load active data
always_ff@(posedge clk, negedge rst_n) begin
	if(~rst_n) begin
		CAL_CS <= IDLE_CAL;
	end else begin
		CAL_CS <= CAL_NS	;
	end
end	

always_comb begin
	CAL_NS = CAL_CS	;
	case (CAL_CS)
	IDLE_CAL: begin
		if(operator_i == CAL_OP && enable_i) begin
			CAL_NS = GET_ACTIVE_DATE;
		end
	end

	GET_ACTIVE_DATE: begin
		if(active_data_cnt != max_weight) begin
			CAL_NS = GET_ACTIVE_DATE;
		end else begin
			CAL_NS = CONFIG_ACTIVE_DATA;
		end
	end

	CONFIG_ACTIVE_DATA: begin
		CAL_NS = CAL_1;
	end

	CAL_1: begin
		CAL_NS = FINISH_CAL;
	end

	FINISH_CAL: begin
		if(ex_ready_i)
			CAL_NS = IDLE_CAL;
	end

	default: begin
		CAL_NS = IDLE_CAL;
	end 
	endcase
end

always_comb begin
	active_ready 	= 1'b0;
	active_active 	= 1'b1;
	active_get_data = 1'b0;
	active_finish 	= 1'b0;

	case (CAL_CS)
	IDLE_CAL: begin
		active_ready 	= 1'b1;
		active_active 	= 1'b0;
		active_get_data = 1'b0;
		active_finish 	= 1'b0;
	end

	GET_ACTIVE_DATE: begin
		active_ready 	= 1'b0;
		active_active 	= 1'b1;
		active_get_data = 1'b1;
		active_finish 	= 1'b0;
	end
	CONFIG_ACTIVE_DATA: begin
		active_ready 	= 1'b0;
		active_active 	= 1'b1;
		active_get_data = 1'b0;
		active_finish 	= 1'b0;

		active_data_splite[0] = active_data[0][15:0];
		active_data_splite[1] = active_data[0][31:16];
		active_data_splite[2] = active_data[1][15:0];
		active_data_splite[3] = active_data[1][31:16];

		$display("active_data_splite[0] = %h", active_data_splite[0]);
		$display("active_data_splite[1] = %h", active_data_splite[1]);
		$display("active_data_splite[2] = %h", active_data_splite[2]);
		$display("active_data_splite[3] = %h", active_data_splite[3]);

	end

	CAL_1: begin
		active_ready 	= 1'b0;
		active_active 	= 1'b1;
		active_get_data = 1'b0;
		active_finish 	= 1'b0;
		if(ACCUM_MODE) begin
			result_data_ACC1[0] = active_data_splite[0] * weight_data_splite[0];
			result_data_ACC1[1] = active_data_splite[1] * weight_data_splite[1];
			result_data_ACC1[2] = active_data_splite[2] * weight_data_splite[2];
			result_data_ACC1[3] = active_data_splite[3] * weight_data_splite[3];

		end else begin 
			result_data_ACC2 = active_data_splite[0] * weight_data_splite[0] 
								+ active_data_splite[1] * weight_data_splite[1] 
								+ active_data_splite[2] * weight_data_splite[2] 
								+ active_data_splite[3] * weight_data_splite[3];
		end

		$display("result_data_ACC1[0] = %h", result_data_ACC1[0]);
		$display("result_data_ACC1[1] = %h", result_data_ACC1[1]);
		$display("result_data_ACC1[2] = %h", result_data_ACC1[2]);
		$display("result_data_ACC1[3] = %h", result_data_ACC1[3]);

		$display("result_data_ACC2 = %d", result_data_ACC2);

	end


	FINISH_CAL: begin
		active_ready 	= 1'b1;
		active_active 	= 1'b0;
		active_get_data = 1'b0;
		active_finish 	= 1'b1;
	end

	default: ;
	endcase

end

//=================================================================//
//============================ WB DATA ============================//
//=================================================================//


always_ff@(posedge clk, negedge rst_n) begin
	if(~rst_n) begin
		WB23_CS <= IDLE_WB;
	end else begin
		WB23_CS <= WB23_NS	;
	end
end

always_comb begin
	wb23_ready = 1'b1;
	WB23_NS = WB23_CS;
	wb23_active = 1'b0;

	case (WB23_CS)
		IDLE_WB: begin
			wb23_ready = 1'b1;
			wb23_active = 1'b0;
			if(operator_i == WB23_OP && enable_i) begin
				WB23_NS = WB23_WDATA;
			end
		end

		WB23_WDATA: begin
			wb23_ready = 1'b0;
			wb23_active = 1'b1;
			if(ACCUM_MODE) begin
				$display("ACCUM_MODE = %d", ACCUM_MODE);
				case(wb_data_cnt < 4) 
					0: mem_wdata = result_data_ACC1[0];
					1: mem_wdata = result_data_ACC1[1];
					2: mem_wdata = result_data_ACC1[2];
					3: begin
						mem_wdata = result_data_ACC1[3];
						wb23_ready = 1'b1;
						WB23_NS = IDLE_WB;
					end
					default: mem_wdata = 32'h0;
				endcase
			end
			else if(!ACCUM_MODE) begin
				if(wb_data_cnt < 1) begin
					mem_wdata = result_data_ACC2;
					$display("!ACCUM_MODE: mem_wdata = %d", mem_wdata);
					wb23_ready = 1'b1;
					WB23_NS = IDLE_WB;
				end
				else mem_wdata = 32'h0;
			end
			else begin
				WB23_NS = IDLE_WB;
				wb23_active = 1'b0;
				wb23_ready = 1'b1;
			end
		end

	endcase

end


endmodule
