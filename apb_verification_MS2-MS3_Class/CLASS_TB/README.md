# Class-based Testbench

Milestone 2

Coverage Groups (per the VP):

FV-001 (cg_reset): implemented in SCOREBOARD.sv. Scoreboard receives the data directly from the output monitor and can check if the very first read transactions return the 0x00000000 default state before any writes can alter the memory.

FV-002 (cg_APB_phases): new class PROTOCOL_COVERAGE created in CLASS_TB. Standard monitors only look at completed transactions. FV-002 requires cycle-by-cycle visibility into the internal bus_if to watch the psel and penable signals transition between the IDLE, SETUP, and ACCESS states.

FV-003 (cg_protocol): implemented in MONITOR_OUT.sv. Tracks error versus no-error states. Output Monitor watches APB Master's response signals (specifically transfer_status which captures pslverr)

FV-004 (cg_data_integrity): To verify data integrity, the covergroup cross references the data being written and data being read for specific patterns like 0xFFFFFFFF

