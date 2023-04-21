\m4_TLV_version 1d: tl-x.org
\SV
   // This code can be found in: https://github.com/stevehoover/LF-Building-a-RISC-V-CPU-Core/risc-v_shell.tlv
   
   m4_include_lib(['https://raw.githubusercontent.com/stevehoover/warp-v_includes/1d1023ccf8e7b0a8cf8e8fc4f0a823ebb61008e3/risc-v_defs.tlv'])
   m4_include_lib(['https://raw.githubusercontent.com/stevehoover/LF-Building-a-RISC-V-CPU-Core/main/lib/risc-v_shell_lib.tlv'])



   //---------------------------------------------------------------------------------
   // Chapter 5 test programme
   m4_test_prog()
   //---------------------------------------------------------------------------------



\SV
   m4_makerchip_module   // (Expanded in Nav-TLV pane.)
   /* verilator lint_on WIDTH */
\TLV
   
   $reset = *reset;
   
   // YOUR CODE HERE
   // Step 1: PC - Create a programme counter
   $next_pc[31:0] = $reset ? 32'b0 :
                    ($taken_br || $is_jal) ? $br_tgt_pc :
                    $is_jalr ? $jalr_tgt_pc :
                    >>1$pc[31:0] + 32'b0100; // Note: default next PC just fixed incremental PC unless a branch is taken   
   $pc[31:0] = $reset ? 32'b0 : $next_pc;
   
   // Step 2: INSTR - Fetch the instruction from the ROM using the programme counter as memory address
   `READONLY_MEM(>>1$pc, $$instr[31:0]);
   
   // Step 3: INSTR TYPE - Classify the fetched instruction by type field instr[6:2]
   $is_i_instr = $instr[6:2] ==? 5'b0000x || $instr[6:2] ==? 5'b001x0 || $instr[6:2] == 5'b11001;
   $is_r_instr = $instr[6:2] == 5'b01011 || $instr[6:2] ==? 5'b011x0 || $instr[6:2] == 5'b10100 ;
   $is_s_instr = $instr[6:2] ==? 5'b0100x;
   $is_b_instr = $instr[6:2] == 5'b11000;
   $is_j_instr = $instr[6:2] == 5'b11011;
   $is_u_instr = $instr[6:2] ==? 5'b0x101;
   
   // Step 4: FIELD 1 - Parse the instruction field with fixed position and validate them
   $funct7[6:0] = $instr[31:25];
   $funct7_valid = $is_r_instr;
   $rs2[4:0] = $instr[24:20];
   $rs2_valid = $is_r_instr || $is_s_instr || $is_b_instr;
   $rs1[4:0] = $instr[19:15];
   $rs1_valid = $is_r_instr || $is_i_instr || $is_s_instr || $is_b_instr;
   $funct3[2:0] = $instr[14:12];
   $funct3_valid = $is_r_instr || $is_i_instr || $is_s_instr || $is_b_instr;
   $rd[4:0] = $instr[11:7];
   $rd_valid = $is_r_instr || $is_i_instr || $is_u_instr || $is_j_instr; // Note: fixed the bug not including U- and J-type instructions in chapter 4
   $opcode[6:0] = $instr[6:0];
   `BOGUS_USE($rs2 $rs2_valid $rs1 $rs1_valid $funct3 $funct3_valid $rd $rd_valid); // Note: to suppress warnings of these signals in log file
   
   // Step 5: FIELD 2 (IMM) - Parse the immediate values with different instruction types
   $imm_valid = $is_i_instr || $is_s_instr || $is_b_instr || $is_u_instr || $is_j_instr;
   $imm[31:0] = $is_i_instr ? { {21{$instr[31]}}, $instr[30:20] } :
                $is_s_instr ? { {21{$instr[31]}}, $instr[30:25], $instr[11:7] } :
                $is_b_instr ? { {20{$instr[31]}}, $instr[7], $instr[30:25], $instr[11:8], 1'b0 } :
                $is_u_instr ? { $instr[31:12], 12'b0 } :
                $is_j_instr ? { {12{$instr[31]}}, $instr[19:12], $instr[20], $instr[30:25], $instr[24:21], 1'b0 } :
                32'b0; // Note: default value
   
   // Step 6: DECODE LOGIC - Extract bits of interest for decode purpose
   // In chapter 5, all decoded logics are added
   $dec_bits[10:0] = {$instr[30], $funct3, $opcode};
   $is_lui = $dec_bits ==? 11'bx_xxx_0110111;
   $is_auipc = $dec_bits ==? 11'bx_xxx_0010111;
   $is_jal = $dec_bits ==? 11'bx_xxx_1101111;
   $is_jalr = $dec_bits ==? 11'bx_000_1100111;
   $is_beq = $dec_bits ==? 11'bx_000_1100011;
   $is_bne = $dec_bits ==? 11'bx_001_1100011;
   $is_blt = $dec_bits ==? 11'bx_100_1100011;
   $is_bge = $dec_bits ==? 11'bx_101_1100011;
   $is_bltu = $dec_bits ==? 11'bx_110_1100011;
   $is_bgeu = $dec_bits ==? 11'bx_111_1100011;
   //$is_lb = $dec_bits ==? 11'bx_000_0000011;
   //$is_lh = $dec_bits ==? 11'bx_001_0000011;
   //$is_lw = $dec_bits ==? 11'bx_010_0000011;
   //$is_lbu = $dec_bits ==? 11'bx_100_0000011;
   //$is_lhu = $dec_bits ==? 11'bx_101_0000011;
   $is_load = $dec_bits ==? 11'bx_xxx_0000011; //use single identifier for all load
   //$is_sb = $dec_bits ==? 11'bx_000_0100011;
   //$is_sh = $dec_bits ==? 11'bx_001_0100011;
   //$is_sw = $dec_bits ==? 11'bx_010_0100011; S instruction already identified store
   $is_addi = $dec_bits ==? 11'bx_000_0010011;
   $is_slti = $dec_bits ==? 11'bx_010_0010011;
   $is_sltiu = $dec_bits ==? 11'bx_011_0010011;
   $is_xori = $dec_bits ==? 11'bx_100_0010011;
   $is_ori = $dec_bits ==? 11'bx_110_0010011;
   $is_andi = $dec_bits ==? 11'bx_111_0010011;
   $is_slli = $dec_bits ==? 11'b0_001_0010011;
   $is_srli = $dec_bits ==? 11'b0_101_0010011;
   $is_srai = $dec_bits ==? 11'b1_101_0010011;
   $is_add = $dec_bits == 11'b0_000_0110011;
   $is_sub = $dec_bits ==? 11'b1_000_0110011;
   $is_sll = $dec_bits ==? 11'b0_001_0110011;
   $is_slt = $dec_bits ==? 11'b0_010_0110011;
   $is_sltu = $dec_bits ==? 11'b0_011_0110011;
   $is_xor = $dec_bits ==? 11'b0_100_0110011;
   $is_srl = $dec_bits ==? 11'b0_101_0110011;
   $is_sra = $dec_bits ==? 11'b1_101_0110011;
   $is_or = $dec_bits ==? 11'b0_110_0110011;
   $is_and = $dec_bits ==? 11'b0_111_0110011;
   
   // Step 8: ALU - Create the ALU for arithmetic and logic operations (only support ADDI and ADD)
   // In chapter 5, all operations are added
   // SLTU and SLTI (set if less than, unsigned) results:
   $sltu_rslt[31:0] = {31'b0, $src1_value < $src2_value};
   $sltiu_rslt[31:0] = {31'b0, $src1_value < $imm};
   // SRA and SRAI (shift right, arithmetic) results:
   //		signed-extended src1
   $sext_src1[63:0] = { {32{$src1_value[31]}}, $src1_value };
   //		64-bit sign-extended resultsm to be truncated
   $sra_rslt[63:0] = $sext_src1 >> $src2_value[4:0];
   $srai_rslt[63:0] = $sext_src1 >> $imm[4:0];
   // ALU results with full operation expansion (result_raw is used as DMEM MUX for load data is added)
   $result_raw[31:0] = $is_andi ? $src1_value & $imm :
                   $is_ori ? $src1_value | $imm :
                   $is_xori ? $src1_value ^ $imm :
                   ($is_addi || $is_load || $is_s_instr) ? $src1_value + $imm :
                   $is_slli ? $src1_value << $imm[5:0] :
                   $is_srli ? $src1_value >> $imm[5:0] :
                   $is_and ? $src1_value & $src2_value :
                   $is_or ? $src1_value | $src2_value :
                   $is_xor ? $src1_value ^ $src2_value :
                   $is_add ? $src1_value + $src2_value :
                   $is_sub ? $src1_value - $src2_value :
                   $is_sll ? $src1_value << $src2_value[4:0] :
                   $is_srl ? $src1_value >> $src2_value[4:0] :
                   $is_sltu ? $sltu_rslt :
                   $is_sltiu ? $sltiu_rslt :
                   $is_lui ? {$imm[31:12], 12'b0} :
                   $is_auipc ? >>1$pc + $imm : // the pc in this context should be the corresponding instruction executed
                   $is_jal ? >>1$pc + 32'd4 :  // the pc in this context should be the corresponding instruction executed
                   $is_jalr ? >>1$pc + 32'd4 : // the pc in this context should be the corresponding instruction executed
                   $is_slt ? ( ($src1_value[31] == $src2_value[31]) ? $sltu_rslt :
                                                                     {31'b0, $src1_value[31]} ) :
                   $is_slti ? ( ($src1_value[31] == $src2_value[31]) ? $sltiu_rslt :
                                                                     {31'b0, $src1_value[31]} ) :
                   $is_sra ? $sra_rslt[31:0] :
                   $is_srai ? $srai_rslt[31:0] :
                   32'b0; // Note: default value
   
   // Step 9: RF/X0 - Register file IO and prevent register X0 written to non-zero value by deasserting $wr_en and additional logic made to enable write back
   $wr_en = ( !($rd == 5'b0 && $result != 32'b0) ) && $rd_valid;
   $rd1_en = $rs1_valid;
   $rd2_en = $rs2_valid;
   
   // Step 13: DMEM LS - Load and store for dynamic memory
   $addr[4:0] = $result_raw[4:0];
   $wr_en_d = $is_s_instr;
   $wr_data[31:0] = $src2_value;
   $rd_en = $is_load;
   $ld_data[31:0] = $rd_data;
   $result[31:0] = $is_load ? $ld_data : $result_raw;
   
   // Step 10: BRANCH (and Jump) - Create branch taker with decoding logic
   $taken_br = $is_beq ? $src1_value == $src2_value :
               $is_bne ? $src1_value != $src2_value :
               $is_blt ? ($src1_value < $src2_value) ^ ($src1_value[31] != $src2_value[31]) :
               $is_bge ? ($src1_value >= $src2_value) ^ ($src1_value[31] != $src2_value[31]) :
               $is_bltu ? $src1_value < $src2_value :
               $is_bgeu ? $src1_value >= $src2_value :
               1'b0; // Note: default value
   $br_tgt_pc[31:0] = >>1$pc + $imm;
   // Additional jumping logic for JALR
   $jalr_tgt_pc[31:0] = $src1_value + $imm;
   
   // Assert these to end simulation (before Makerchip cycle limit).
   // Step 11: TB - Import testbench to verify logic
   m4+tb()
   // *passed = 1'b0; // Original passed criteria is commented
   *failed = *cyc_cnt > M4_MAX_CYC;
   
   // Step 7: REGISTER FILE - Instantiate the register bank for different operations
   m4+rf(32, 32, $reset, $wr_en, $rd[4:0], $result[31:0], $rd1_en, $rs1[4:0], $src1_value, $rd2_en, $rs2[4:0], $src2_value)
   // Step 12: DMEM - Dynamic memory added for load-store instructions
   m4+dmem(32, 32, $reset, $addr[4:0], $wr_en_d, $wr_data[31:0], $rd_en, $rd_data)
   m4+cpu_viz()
\SV
   endmodule