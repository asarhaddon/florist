------------------------------------------------------------------------------
--                                                                          --
--                      POSIX.5b VALIDATION TEST SUITE                      --
--                                                                          --
--                            P 9 9 0 0 0 2 b                               --
--                                                                          --
--                                B o d y                                   --
--                                                                          --
--                                                                          --
--  Copyright (c) 1998      Florida  State  University  (FSU).  All Rights  --
--  Reserved.                                                               --
--                                                                          --
--  This is free software;  you can redistribute it and/or modify it under  --
--  terms of the  GNU  General  Public  License  as published by the  Free  --
--  Software Foundation;  either version 2, or (at your option) any  later  --
--  version.  This  software  is distributed  in the hope that it  will be  --
--  useful, but WITHOUT ANY WARRANTY; without even the implied warranty of  --
--  MERCHANTABILITY   or  FITNESS FOR A PARTICULAR PURPOSE.   See the  GNU  --
--  General Public License for more details.  You  should have  received a  --
--  copy of the GNU General Public License  distributed  with  GNARL;  see  --
--  file  COPYING.  If not,  write to  the  Free  Software  Foundation, 59  --
--  Temple Place - Suite 330, Boston, MA 02111-1307, USA.                   --
--                                                                          --
--  Under contract  GS-35F-4506G, the U. S. Government obtained  unlimited  --
--  rights in the software and documentation contained herein.   Unlimited  --
--  rights are defined in DFAR 252,227-7013(a)(19).  By making this public  --
--  release,   the  Government  intends  to  confer  upon  all  recipients  --
--  unlimited  rights equal to those held by the Government.  These rights  --
--  include rights to use,  duplicate,  release  or  disclose the released  --
--  data an computer software  in whole or in part,  in any manner and for  --
--  any purpose whatsoever, and to have or permit others to do so.          --
--                                                                          --
--  DISCLAIMER   --   ALL MATERIALS OR INFORMATION HEREIN RELEASED,   MADE  --
--  AVAILABLE OR DISCLOSED ARE AS IS.   THE GOVERNMENT MAKES NO EXPRESS OR  --
--  IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING THE CONDITIONS  --
--  OF THE SOFTWARE,  DOCUMENTATION  OR  OTHER INFORMATION RELEASED,  MADE  --
--  AVAILABLE OR DISCLOSED,  OR THE OWNERSHIP,  MERCHANTABILITY, OR FITNESS  --
--  FOR A PARTICULAR PURPOSE OF SAID MATERIAL.                              --
--                                                                          --
------------------------------------------------------------------------------
--  [$Revision$]

with P990000,
     POSIX,
     POSIX_Mutexes,
     POSIX_Condition_Variables,
     POSIX_Timers,
     POSIX_Report;
package body P990002b is

   use P990000,
       POSIX,
       POSIX_Mutexes,
       POSIX_Condition_Variables,
       POSIX_Timers,
       POSIX_Report;

   function Clock return Timespec;
   function Clock return Timespec is
   begin
      return Get_Time (Clock_Realtime);
   end Clock;

   Zero : constant Timespec := To_Timespec (0, 0);
   Start_Time,
   Stop_Time : Timespec;
   Next_Request_Time : array (Jobs) of Timespec;

   M : Mutex;
   C : Condition;
   MA : POSIX_Mutexes.Attributes;
   CA : POSIX_Condition_Variables.Attributes;
   MD : Mutex_Descriptor;
   CD : Condition_Descriptor;

   Data : Shared_Data_Ptr;

   procedure Initialize_Scheduling (Shared_Data : Shared_Data_Ptr) is
   begin
      Data := Shared_Data;
      Start_Time := Data.Start_Timespec;
      Stop_Time := Start_Time +
        POSIX.To_Timespec (Seconds (Seconds_To_Run), 0);
      Next_Request_Time := (others => Start_Time);
   exception when E : others => Fatal_Exception (E, "A001: P990002b");
   end Initialize_Scheduling;

   function Reschedule (Job : Jobs) return Boolean is
      Last_Completion_Time,
      Time_To_Next_Request : Timespec;
      Missed_Periods : Integer;
   begin
      Next_Request_Time (Job) := Next_Request_Time (Job) +
        To_Timespec (Period (Job));
      Last_Completion_Time := Clock;
      Time_To_Next_Request := Next_Request_Time (Job) - Last_Completion_Time;
      if Time_To_Next_Request < Zero then
         if not Data.Missed_Deadlines then
            Data.Missed_Deadlines := True;
            Comment ("lateness", Time_To_Next_Request);
         end if;
         Missed_Periods := 0;
         while Time_To_Next_Request < Zero loop
            Time_To_Next_Request := Time_To_Next_Request +
              To_Timespec (Period (Job));
            Missed_Periods := Missed_Periods + 1;
         end loop;
         Next_Request_Time (Job) :=
           Next_Request_Time (Job) +
             Missed_Periods * To_Timespec (Period (Job));
      end if;
      if Next_Request_Time (Job) >= Stop_Time then
         return False;
      end if;
      Lock (MD);
      loop
         begin
            Timed_Wait (CD, MD, Next_Request_Time (Job));
         exception
         when POSIX_Error =>
            --  The only error return here shoud be if we timed out.
            Assert (Get_Error_Code = Timed_Out, "A002: P990002b");
         when E : others => Unexpected_Exception (E, "A003: P990002b");
         end;
         exit when Clock >= Next_Request_Time (Job);
      end loop;
      Unlock (MD);
      return True;
   exception when E : others => Fatal_Exception (E, "A004: P990002b");
      return False;
   end Reschedule;

   procedure Finalize is
   begin
      null;
   end Finalize;

begin
   Optional (Mutex_Option, "A005: P990002b");
   Optional (Timers_Option, "A006: P990002b");
   Initialize (MA);
   begin
      Set_Locking_Policy (MA, Highest_Ceiling_Priority);
      Initialize (M, MA);
   exception
   when E1 : POSIX_Error =>
      Optional (Mutex_Option, Mutex_Priority_Ceiling_Option,
        Operation_Not_Implemented, E1, "A007: P990002b");
      Initialize (MA);
      Initialize (M, MA);
   end;
   MD := Descriptor_Of (M);
   Initialize (CA);
   Initialize (C, CA);
   CD := Descriptor_Of (C);
exception when E : others => Fatal_Exception (E, "A008: P99002b");
end P990002b;
