package body Itklib.Core.Regions with SPARK_Mode => On is

   function Product_Bounded (Extent : Size) return Boolean is
      Acc : Interfaces.Unsigned_64 := 1;
   begin
      for A in Axis loop
         pragma Loop_Invariant (Acc >= 1);
         if Extent (A) = 0
           or else Acc > Interfaces.Unsigned_64'Last / Extent (A)
         then
            return False;
         end if;
         Acc := Acc * Extent (A);
      end loop;
      return True;
   end Product_Bounded;

   function Volume (Extent : Size) return Interfaces.Unsigned_64 is
      Acc : Interfaces.Unsigned_64 := 1;
   begin
      for A in Axis loop
         pragma Loop_Invariant (Acc >= 1);
         if Extent (A) = 0
           or else Acc > Interfaces.Unsigned_64'Last / Extent (A)
         then
            return Acc;
         end if;
         Acc := Acc * Extent (A);
      end loop;
      return Acc;
   end Volume;

   function Offset (R : Region; Idx : Index) return Interfaces.Unsigned_64 is
      Acc : Interfaces.Unsigned_64 := 0;
      Stride : Interfaces.Unsigned_64 := 1;
   begin
      for A in Axis loop
         pragma Loop_Invariant (Stride >= 1);
         declare
            Delta_I : constant Interfaces.Unsigned_64 :=
              Interfaces.Unsigned_64 (Idx (A) - R.Start (A));
            Product : Interfaces.Unsigned_64;
         begin
            if Delta_I /= 0
              and then Stride > Interfaces.Unsigned_64'Last / Delta_I
            then
               return Acc;
            end if;
            Product := Delta_I * Stride;
            if Product > Interfaces.Unsigned_64'Last - Acc then
               return Acc;
            end if;
            Acc := Acc + Product;
            if R.Extent (A) = 0
              or else Stride > Interfaces.Unsigned_64'Last / R.Extent (A)
            then
               return Acc;
            end if;
            Stride := Stride * R.Extent (A);
         end;
      end loop;
      return Acc;
   end Offset;

   function Index_At
     (R : Region; Off : Interfaces.Unsigned_64) return Index
   is
      Result : Index := R.Start;
      Rest : Interfaces.Unsigned_64 := Off;
   begin
      for A in Axis loop
         pragma Loop_Invariant (Rest <= Off);
         declare
            Step : constant Interfaces.Unsigned_64 := Rest mod R.Extent (A);
            Step_I : constant Interfaces.Integer_64 := Interfaces.Integer_64 (Step);
         begin
            if R.Start (A) >= 0
              and then Step_I > Interfaces.Integer_64'Last - R.Start (A)
            then
               Result (A) := R.Start (A);
            else
               Result (A) := R.Start (A) + Step_I;
            end if;
            Rest := Rest / R.Extent (A);
         end;
      end loop;
      return Result;
   end Index_At;

   function First (R : Region) return Cursor is
   begin
      return (Subject => R, Off => 0, At_End => False);
   end First;

   function Next (C : Cursor) return Cursor is
      Last_Off : constant Interfaces.Unsigned_64 :=
        Volume (C.Subject.Extent) - 1;
   begin
      if C.Off >= Last_Off then
         return (Subject => C.Subject, Off => C.Off, At_End => True);
      end if;
      return (Subject => C.Subject, Off => C.Off + 1, At_End => False);
   end Next;

   function Index_Of (C : Cursor) return Index is
   begin
      return Index_At (C.Subject, C.Off);
   end Index_Of;

   procedure Walk (R : Region) is
      Count : constant Interfaces.Unsigned_64 := Volume (R.Extent);
      Off : Interfaces.Unsigned_64 := 0;
   begin
      while Off < Count loop
         pragma Loop_Invariant (Off < Count);
         pragma Loop_Invariant (Off < Interfaces.Unsigned_64'Last);
         Visit (Index_At (R, Off), Off);
         Off := Off + 1;
      end loop;
   end Walk;

   function To_Physical
     (Idx : Index; Spacing : Vector; Origin : Vector; Direction : Matrix)
      return Vector
   with SPARK_Mode => Off
   is
      Result : Vector := Origin;
   begin
      for Row in Axis loop
         for Column in Axis loop
            Result (Row) :=
              Result (Row) +
              Direction (Row, Column) * Spacing (Column) *
                Long_Float (Idx (Column));
         end loop;
      end loop;
      return Result;
   end To_Physical;

   function Round_Index (Value : Long_Float) return Interfaces.Integer_64 with
     SPARK_Mode => Off
   is
      Shifted : constant Long_Float := Long_Float'Floor (Value + 0.5);
   begin
      return Interfaces.Integer_64 (Shifted);
   end Round_Index;

   function To_Index
     (Point : Vector; Spacing : Vector; Origin : Vector; Direction : Matrix)
      return Index
   with SPARK_Mode => Off
   is
      --  Solve direction * y = point - origin, then index = round(y / spacing).
      --  Rows stay inside Axis, so the same body instantiates for 2D and 3D.
      Factor : Matrix := Direction;
      Rhs : Vector;
      Result : Index := [others => 0];
      Singular : Boolean := False;
   begin
      for A in Axis loop
         Rhs (A) := Point (A) - Origin (A);
      end loop;

      for Pivot in Axis loop
         declare
            Pivot_Row : Axis := Pivot;
            Scale : Long_Float;
         begin
            for Row in Axis loop
               if Row >= Pivot
                 and then abs (Factor (Row, Pivot)) > abs (Factor (Pivot_Row, Pivot))
               then
                  Pivot_Row := Row;
               end if;
            end loop;

            if Pivot_Row /= Pivot then
               declare
                  Saved_Row : constant Vector :=
                    [for Column in Axis => Factor (Pivot_Row, Column)];
                  Saved_Rhs : constant Long_Float := Rhs (Pivot_Row);
               begin
                  for Column in Axis loop
                     Factor (Pivot_Row, Column) := Factor (Pivot, Column);
                     Factor (Pivot, Column) := Saved_Row (Column);
                  end loop;
                  Rhs (Pivot_Row) := Rhs (Pivot);
                  Rhs (Pivot) := Saved_Rhs;
               end;
            end if;

            if Factor (Pivot, Pivot) = 0.0 then
               Singular := True;
               exit;
            end if;

            for Row in Axis loop
               if Row /= Pivot then
                  Scale := Factor (Row, Pivot) / Factor (Pivot, Pivot);
                  for Column in Axis loop
                     Factor (Row, Column) :=
                       Factor (Row, Column) - Scale * Factor (Pivot, Column);
                  end loop;
                  Rhs (Row) := Rhs (Row) - Scale * Rhs (Pivot);
               end if;
            end loop;
         end;
      end loop;

      if not Singular then
         for A in Axis loop
            Result (A) :=
              Round_Index ((Rhs (A) / Factor (A, A)) / Spacing (A));
         end loop;
      end if;
      return Result;
   end To_Index;

end Itklib.Core.Regions;
