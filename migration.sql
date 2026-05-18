-- Migration for the Lotte Cinema schema.
-- Run this file after cinema.sql.

BEGIN;

--------------------------------------------------------------------------------
-- 1. Employee account and shift design
--------------------------------------------------------------------------------

COMMENT ON COLUMN NhanVien.TaiKhoan IS
    'Deprecated: use TaiKhoanNhanVien.TenDangNhap instead.';

COMMENT ON COLUMN NhanVien.MatKhau IS
    'Deprecated: do not store plain passwords here. Use TaiKhoanNhanVien.MatKhauHash.';

CREATE TABLE IF NOT EXISTS TaiKhoanNhanVien (
    MaTK SERIAL PRIMARY KEY,
    MaNV INT NOT NULL REFERENCES NhanVien(MaNV) ON DELETE CASCADE,
    TenDangNhap VARCHAR(50) NOT NULL UNIQUE,
    MatKhauHash VARCHAR(255) NOT NULL,
    TrangThaiTK VARCHAR(20) NOT NULL DEFAULT 'HoatDong',
    LanDangNhapCuoi TIMESTAMP,
    NgayTao TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO TaiKhoanNhanVien (MaNV, TenDangNhap, MatKhauHash)
SELECT MaNV, TaiKhoan, MatKhau
FROM NhanVien
WHERE TaiKhoan IS NOT NULL
  AND MatKhau IS NOT NULL
ON CONFLICT (TenDangNhap) DO NOTHING;

CREATE TABLE IF NOT EXISTS CaLamViec (
    MaCa SERIAL PRIMARY KEY,
    MaNV INT NOT NULL REFERENCES NhanVien(MaNV) ON DELETE CASCADE,
    TGBatDau TIMESTAMP NOT NULL,
    TGKetThuc TIMESTAMP NOT NULL,
    ViTriLamViec VARCHAR(100) NOT NULL,
    TrangThaiCa VARCHAR(20) NOT NULL DEFAULT 'DaLenLich'
);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = lower('CHK_TaiKhoanNhanVien_TrangThaiTK')
          AND conrelid = 'TaiKhoanNhanVien'::regclass
    ) THEN
        ALTER TABLE TaiKhoanNhanVien
        ADD CONSTRAINT CHK_TaiKhoanNhanVien_TrangThaiTK
        CHECK (TrangThaiTK IN ('HoatDong', 'BiKhoa', 'NgungSuDung'));
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = lower('UQ_TaiKhoanNhanVien_MaNV')
          AND conrelid = 'TaiKhoanNhanVien'::regclass
    ) THEN
        ALTER TABLE TaiKhoanNhanVien
        ADD CONSTRAINT UQ_TaiKhoanNhanVien_MaNV UNIQUE (MaNV);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = lower('CHK_CaLamViec_ThoiGian')
          AND conrelid = 'CaLamViec'::regclass
    ) THEN
        ALTER TABLE CaLamViec
        ADD CONSTRAINT CHK_CaLamViec_ThoiGian CHECK (TGKetThuc > TGBatDau);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = lower('CHK_CaLamViec_TrangThaiCa')
          AND conrelid = 'CaLamViec'::regclass
    ) THEN
        ALTER TABLE CaLamViec
        ADD CONSTRAINT CHK_CaLamViec_TrangThaiCa
        CHECK (TrangThaiCa IN ('DaLenLich', 'DangLam', 'HoanThanh', 'DaHuy'));
    END IF;
END $$;

--------------------------------------------------------------------------------
-- 2. Customer and membership design
--------------------------------------------------------------------------------

ALTER TABLE KhachHang
    ADD COLUMN IF NOT EXISTS NgayDangKy TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ADD COLUMN IF NOT EXISTS TrangThaiKH VARCHAR(20) NOT NULL DEFAULT 'HoatDong';

CREATE TABLE IF NOT EXISTS HangThanhVien (
    HangTVien VARCHAR(50) PRIMARY KEY,
    MucChiTieuToiThieu DECIMAL(12, 2) NOT NULL DEFAULT 0,
    TyLeGiamGia DECIMAL(5, 2) NOT NULL DEFAULT 0,
    MoTa VARCHAR(255)
);

INSERT INTO HangThanhVien (HangTVien, MucChiTieuToiThieu, TyLeGiamGia, MoTa)
VALUES
    ('Thuong', 0, 0, 'Default member tier'),
    ('VIP', 5000000, 5, 'VIP member tier'),
    ('VVIP', 15000000, 10, 'VVIP member tier')
ON CONFLICT (HangTVien) DO NOTHING;

UPDATE KhachHang
SET HangTVien = 'Thuong'
WHERE HangTVien IS NULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = lower('FK_KhachHang_HangThanhVien')
          AND conrelid = 'KhachHang'::regclass
    ) THEN
        ALTER TABLE KhachHang
        ADD CONSTRAINT FK_KhachHang_HangThanhVien
        FOREIGN KEY (HangTVien) REFERENCES HangThanhVien(HangTVien);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = lower('CHK_KhachHang_TrangThaiKH')
          AND conrelid = 'KhachHang'::regclass
    ) THEN
        ALTER TABLE KhachHang
        ADD CONSTRAINT CHK_KhachHang_TrangThaiKH
        CHECK (TrangThaiKH IN ('HoatDong', 'NgungHoatDong'));
    END IF;
END $$;

--------------------------------------------------------------------------------
-- 3. Booking, ticket state, and seat validation
--------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS DatVe (
    MaDatVe SERIAL PRIMARY KEY,
    MaKH INT REFERENCES KhachHang(MaKH),
    MaNV INT REFERENCES NhanVien(MaNV),
    NgayDat TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    HanGiuGhe TIMESTAMP,
    TrangThaiDatVe VARCHAR(20) NOT NULL DEFAULT 'GiuCho'
);

ALTER TABLE Ve
    ADD COLUMN IF NOT EXISTS MaDatVe INT REFERENCES DatVe(MaDatVe) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS TrangThaiVe VARCHAR(20) NOT NULL DEFAULT 'DaThanhToan',
    ADD COLUMN IF NOT EXISTS NgayTao TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = lower('UQ_Ve_SuatChieu_Ghe')
          AND conrelid = 'Ve'::regclass
    ) THEN
        ALTER TABLE Ve DROP CONSTRAINT UQ_Ve_SuatChieu_Ghe;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = lower('CHK_DatVe_TrangThaiDatVe')
          AND conrelid = 'DatVe'::regclass
    ) THEN
        ALTER TABLE DatVe
        ADD CONSTRAINT CHK_DatVe_TrangThaiDatVe
        CHECK (TrangThaiDatVe IN ('GiuCho', 'DaThanhToan', 'DaHuy', 'HetHan'));
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = lower('CHK_DatVe_HanGiuGhe')
          AND conrelid = 'DatVe'::regclass
    ) THEN
        ALTER TABLE DatVe
        ADD CONSTRAINT CHK_DatVe_HanGiuGhe
        CHECK (HanGiuGhe IS NULL OR HanGiuGhe > NgayDat);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = lower('CHK_Ve_TrangThaiVe')
          AND conrelid = 'Ve'::regclass
    ) THEN
        ALTER TABLE Ve
        ADD CONSTRAINT CHK_Ve_TrangThaiVe
        CHECK (TrangThaiVe IN ('GiuCho', 'DaThanhToan', 'DaSuDung', 'DaHuy'));
    END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS UQ_Ve_SuatChieu_Ghe_Active
ON Ve (MaLichChieu, MaGhe)
WHERE TrangThaiVe IN ('GiuCho', 'DaThanhToan', 'DaSuDung');

CREATE OR REPLACE FUNCTION trg_CheckTicketSeatRoom()
RETURNS TRIGGER AS $$
DECLARE
    v_PhongLichChieu INT;
    v_PhongGhe INT;
BEGIN
    IF NEW.MaLichChieu IS NULL OR NEW.MaGhe IS NULL THEN
        RETURN NEW;
    END IF;

    SELECT MaPhong INTO v_PhongLichChieu
    FROM LichChieu
    WHERE MaLichChieu = NEW.MaLichChieu;

    SELECT MaPhong INTO v_PhongGhe
    FROM Ghe
    WHERE MaGhe = NEW.MaGhe;

    IF v_PhongLichChieu IS DISTINCT FROM v_PhongGhe THEN
        RAISE EXCEPTION 'LỖI NGHIỆP VỤ: Ghế (Mã: %) không thuộc phòng của lịch chiếu (Mã: %).',
            NEW.MaGhe, NEW.MaLichChieu;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_check_ve_ghe_phong ON Ve;
CREATE TRIGGER trigger_check_ve_ghe_phong
BEFORE INSERT OR UPDATE OF MaLichChieu, MaGhe ON Ve
FOR EACH ROW EXECUTE FUNCTION trg_CheckTicketSeatRoom();

--------------------------------------------------------------------------------
-- 4. Invoice, payment, and tax design
--------------------------------------------------------------------------------

ALTER TABLE HoaDon
    ADD COLUMN IF NOT EXISTS MaDatVe INT REFERENCES DatVe(MaDatVe) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS TyLeThue DECIMAL(5, 2) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS TienThue DECIMAL(12, 2) NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS ThanhToan (
    MaThanhToan SERIAL PRIMARY KEY,
    MaHD INT NOT NULL REFERENCES HoaDon(MaHD) ON DELETE CASCADE,
    MaNV INT REFERENCES NhanVien(MaNV),
    SoTien DECIMAL(12, 2) NOT NULL,
    ThoiGianThanhToan TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PhuongThuc VARCHAR(50) NOT NULL,
    TrangThaiTT VARCHAR(20) NOT NULL DEFAULT 'ThanhCong',
    MaGiaoDich VARCHAR(100)
);

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = lower('CHK_HoaDon_LogicTien')
          AND conrelid = 'HoaDon'::regclass
    ) THEN
        ALTER TABLE HoaDon DROP CONSTRAINT CHK_HoaDon_LogicTien;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = lower('CHK_HoaDon_TyLeThue')
          AND conrelid = 'HoaDon'::regclass
    ) THEN
        ALTER TABLE HoaDon
        ADD CONSTRAINT CHK_HoaDon_TyLeThue CHECK (TyLeThue >= 0);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = lower('CHK_HoaDon_TienThue')
          AND conrelid = 'HoaDon'::regclass
    ) THEN
        ALTER TABLE HoaDon
        ADD CONSTRAINT CHK_HoaDon_TienThue CHECK (TienThue >= 0);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = lower('CHK_HoaDon_LogicTien_WithTax')
          AND conrelid = 'HoaDon'::regclass
    ) THEN
        ALTER TABLE HoaDon
        ADD CONSTRAINT CHK_HoaDon_LogicTien_WithTax
        CHECK (ThanhTien = GREATEST(TongTien - GiamGia, 0) + TienThue);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = lower('CHK_ThanhToan_SoTien')
          AND conrelid = 'ThanhToan'::regclass
    ) THEN
        ALTER TABLE ThanhToan
        ADD CONSTRAINT CHK_ThanhToan_SoTien CHECK (SoTien >= 0);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = lower('CHK_ThanhToan_PhuongThuc')
          AND conrelid = 'ThanhToan'::regclass
    ) THEN
        ALTER TABLE ThanhToan
        ADD CONSTRAINT CHK_ThanhToan_PhuongThuc
        CHECK (PhuongThuc IN ('Tiền mặt', 'Thẻ', 'Ví điện tử'));
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = lower('CHK_ThanhToan_TrangThaiTT')
          AND conrelid = 'ThanhToan'::regclass
    ) THEN
        ALTER TABLE ThanhToan
        ADD CONSTRAINT CHK_ThanhToan_TrangThaiTT
        CHECK (TrangThaiTT IN ('ChoXuLy', 'ThanhCong', 'ThatBai', 'HoanTien'));
    END IF;
END $$;

CREATE OR REPLACE FUNCTION trg_CalculateInvoiceTotal()
RETURNS TRIGGER AS $$
DECLARE
    v_MaHD INT;
    v_TienVe DECIMAL(12,2) := 0;
    v_TienSP DECIMAL(12,2) := 0;
    v_TongTien DECIMAL(12,2) := 0;
    v_GiamGia DECIMAL(12,2) := 0;
    v_TyLeThue DECIMAL(5,2) := 0;
    v_TienThue DECIMAL(12,2) := 0;
    v_TrangThai VARCHAR(20);
BEGIN
    IF (TG_OP = 'DELETE') THEN
        v_MaHD := OLD.MaHD;
    ELSE
        v_MaHD := NEW.MaHD;
    END IF;

    SELECT TrangThaiHD, GiamGia, TyLeThue
    INTO v_TrangThai, v_GiamGia, v_TyLeThue
    FROM HoaDon
    WHERE MaHD = v_MaHD;

    IF v_TrangThai = 'DaThanhToan' THEN
        RAISE EXCEPTION 'LỖI BẢO MẬT: Không thể chỉnh sửa nội dung (Vé/Sản phẩm) của hóa đơn đã thanh toán!';
    END IF;

    SELECT COALESCE(SUM(GiaVe), 0)
    INTO v_TienVe
    FROM Ve
    WHERE MaHD = v_MaHD
      AND TrangThaiVe <> 'DaHuy';

    SELECT COALESCE(SUM(SoLuong * DonGia), 0)
    INTO v_TienSP
    FROM CT_HD_SanPham
    WHERE MaHD = v_MaHD;

    v_TongTien := v_TienVe + v_TienSP;
    v_TienThue := ROUND(GREATEST(v_TongTien - v_GiamGia, 0) * v_TyLeThue / 100, 2);

    UPDATE HoaDon
    SET TongTien = v_TongTien,
        TienThue = v_TienThue,
        ThanhTien = GREATEST(v_TongTien - v_GiamGia, 0) + v_TienThue
    WHERE MaHD = v_MaHD;

    IF (TG_OP = 'DELETE') THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_tinhtien_ve ON Ve;
DROP TRIGGER IF EXISTS trigger_tinhtien_ve_insert ON Ve;
DROP TRIGGER IF EXISTS trigger_tinhtien_ve_update ON Ve;
DROP TRIGGER IF EXISTS trigger_tinhtien_ve_delete ON Ve;

CREATE TRIGGER trigger_tinhtien_ve_insert
AFTER INSERT ON Ve
FOR EACH ROW EXECUTE FUNCTION trg_CalculateInvoiceTotal();

CREATE TRIGGER trigger_tinhtien_ve_update
AFTER UPDATE OF MaHD, GiaVe, TrangThaiVe ON Ve
FOR EACH ROW EXECUTE FUNCTION trg_CalculateInvoiceTotal();

CREATE TRIGGER trigger_tinhtien_ve_delete
AFTER DELETE ON Ve
FOR EACH ROW EXECUTE FUNCTION trg_CalculateInvoiceTotal();

DROP TRIGGER IF EXISTS trigger_tinhtien_sp ON CT_HD_SanPham;
DROP TRIGGER IF EXISTS trigger_tinhtien_sp_insert ON CT_HD_SanPham;
DROP TRIGGER IF EXISTS trigger_tinhtien_sp_update ON CT_HD_SanPham;
DROP TRIGGER IF EXISTS trigger_tinhtien_sp_delete ON CT_HD_SanPham;

CREATE TRIGGER trigger_tinhtien_sp_insert
AFTER INSERT ON CT_HD_SanPham
FOR EACH ROW EXECUTE FUNCTION trg_CalculateInvoiceTotal();

CREATE TRIGGER trigger_tinhtien_sp_update
AFTER UPDATE OF MaHD, SoLuong, DonGia ON CT_HD_SanPham
FOR EACH ROW EXECUTE FUNCTION trg_CalculateInvoiceTotal();

CREATE TRIGGER trigger_tinhtien_sp_delete
AFTER DELETE ON CT_HD_SanPham
FOR EACH ROW EXECUTE FUNCTION trg_CalculateInvoiceTotal();

CREATE OR REPLACE FUNCTION trg_NormalizeInvoiceMoney()
RETURNS TRIGGER AS $$
BEGIN
    NEW.TongTien := COALESCE(NEW.TongTien, 0);
    NEW.GiamGia := COALESCE(NEW.GiamGia, 0);
    NEW.TyLeThue := COALESCE(NEW.TyLeThue, 0);
    NEW.TienThue := ROUND(GREATEST(NEW.TongTien - NEW.GiamGia, 0) * NEW.TyLeThue / 100, 2);
    NEW.ThanhTien := GREATEST(NEW.TongTien - NEW.GiamGia, 0) + NEW.TienThue;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_normalize_hoadon_money ON HoaDon;
CREATE TRIGGER trigger_normalize_hoadon_money
BEFORE INSERT OR UPDATE OF TongTien, GiamGia, TyLeThue ON HoaDon
FOR EACH ROW EXECUTE FUNCTION trg_NormalizeInvoiceMoney();

--------------------------------------------------------------------------------
-- 5. Product and showtime improvements
--------------------------------------------------------------------------------

ALTER TABLE SanPham
    ADD COLUMN IF NOT EXISTS TrangThaiSP VARCHAR(20) NOT NULL DEFAULT 'ConBan';

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = lower('CHK_SanPham_TrangThaiSP')
          AND conrelid = 'SanPham'::regclass
    ) THEN
        ALTER TABLE SanPham
        ADD CONSTRAINT CHK_SanPham_TrangThaiSP
        CHECK (TrangThaiSP IN ('ConBan', 'HetHang', 'NgungBan'));
    END IF;
END $$;

CREATE OR REPLACE FUNCTION trg_SetShowtimeEndTime()
RETURNS TRIGGER AS $$
DECLARE
    v_ThoiLuong INT;
BEGIN
    SELECT ThoiLuong INTO v_ThoiLuong
    FROM Phim
    WHERE MaPhim = NEW.MaPhim;

    IF v_ThoiLuong IS NOT NULL THEN
        NEW.TGKetThuc := NEW.TGBatDau + (v_ThoiLuong || ' minutes')::INTERVAL;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_set_lichchieu_end_time ON LichChieu;
CREATE TRIGGER trigger_set_lichchieu_end_time
BEFORE INSERT OR UPDATE OF MaPhim, TGBatDau ON LichChieu
FOR EACH ROW EXECUTE FUNCTION trg_SetShowtimeEndTime();

ALTER TABLE LichChieu
    ALTER COLUMN MaPhim SET NOT NULL,
    ALTER COLUMN MaPhong SET NOT NULL;

ALTER TABLE Ve
    ALTER COLUMN MaLichChieu SET NOT NULL,
    ALTER COLUMN MaGhe SET NOT NULL;

--------------------------------------------------------------------------------
-- 6. Loyalty point history
--------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS LichSuDiem (
    MaLichSuDiem SERIAL PRIMARY KEY,
    MaKH INT NOT NULL REFERENCES KhachHang(MaKH) ON DELETE CASCADE,
    MaHD INT REFERENCES HoaDon(MaHD) ON DELETE SET NULL,
    SoDiem INT NOT NULL,
    LoaiGiaoDich VARCHAR(20) NOT NULL,
    NgayTao TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    GhiChu VARCHAR(255)
);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = lower('CHK_LichSuDiem_LoaiGiaoDich')
          AND conrelid = 'LichSuDiem'::regclass
    ) THEN
        ALTER TABLE LichSuDiem
        ADD CONSTRAINT CHK_LichSuDiem_LoaiGiaoDich
        CHECK (LoaiGiaoDich IN ('Cong', 'Tru', 'DieuChinh'));
    END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS UQ_LichSuDiem_MaHD_Cong
ON LichSuDiem(MaHD)
WHERE LoaiGiaoDich = 'Cong' AND MaHD IS NOT NULL;

CREATE OR REPLACE FUNCTION trg_UpdateInvoiceAfterPayment()
RETURNS TRIGGER AS $$
DECLARE
    v_TongDaTra DECIMAL(12,2) := 0;
    v_ThanhTien DECIMAL(12,2) := 0;
    v_MaKH INT;
    v_MaDatVe INT;
    v_DiemCong INT := 0;
BEGIN
    IF NEW.TrangThaiTT <> 'ThanhCong' THEN
        RETURN NEW;
    END IF;

    SELECT COALESCE(SUM(SoTien), 0)
    INTO v_TongDaTra
    FROM ThanhToan
    WHERE MaHD = NEW.MaHD
      AND TrangThaiTT = 'ThanhCong';

    SELECT ThanhTien, MaKH, MaDatVe
    INTO v_ThanhTien, v_MaKH, v_MaDatVe
    FROM HoaDon
    WHERE MaHD = NEW.MaHD;

    IF v_TongDaTra >= v_ThanhTien THEN
        IF v_MaDatVe IS NOT NULL THEN
            UPDATE DatVe
            SET TrangThaiDatVe = 'DaThanhToan'
            WHERE MaDatVe = v_MaDatVe
              AND TrangThaiDatVe <> 'DaHuy';

            UPDATE Ve
            SET TrangThaiVe = 'DaThanhToan'
            WHERE MaDatVe = v_MaDatVe
              AND TrangThaiVe = 'GiuCho';
        END IF;

        UPDATE HoaDon
        SET TrangThaiHD = 'DaThanhToan',
            PTThanhToan = NEW.PhuongThuc
        WHERE MaHD = NEW.MaHD;

        IF v_MaKH IS NOT NULL
           AND NOT EXISTS (
               SELECT 1 FROM LichSuDiem
               WHERE MaHD = NEW.MaHD
                 AND LoaiGiaoDich = 'Cong'
           ) THEN
            v_DiemCong := FLOOR(v_ThanhTien * 0.05);

            IF v_DiemCong > 0 THEN
                INSERT INTO LichSuDiem (MaKH, MaHD, SoDiem, LoaiGiaoDich, GhiChu)
                VALUES (v_MaKH, NEW.MaHD, v_DiemCong, 'Cong', 'Auto points from paid invoice');

                UPDATE KhachHang
                SET DiemTichLuy = DiemTichLuy + v_DiemCong
                WHERE MaKH = v_MaKH;
            END IF;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_invoice_after_payment ON ThanhToan;
CREATE TRIGGER trigger_update_invoice_after_payment
AFTER INSERT OR UPDATE OF SoTien, TrangThaiTT ON ThanhToan
FOR EACH ROW EXECUTE FUNCTION trg_UpdateInvoiceAfterPayment();

--------------------------------------------------------------------------------
-- 7. Indexes for reporting and FK-heavy joins
--------------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS IDX_HoaDon_MaKH ON HoaDon(MaKH);
CREATE INDEX IF NOT EXISTS IDX_HoaDon_MaNV ON HoaDon(MaNV);
CREATE INDEX IF NOT EXISTS IDX_HoaDon_MaDatVe ON HoaDon(MaDatVe);
CREATE INDEX IF NOT EXISTS IDX_DatVe_MaKH ON DatVe(MaKH);
CREATE INDEX IF NOT EXISTS IDX_DatVe_MaNV ON DatVe(MaNV);
CREATE INDEX IF NOT EXISTS IDX_DatVe_NgayDat ON DatVe(NgayDat);
CREATE INDEX IF NOT EXISTS IDX_Ve_MaDatVe ON Ve(MaDatVe);
CREATE INDEX IF NOT EXISTS IDX_Ve_MaLichChieu ON Ve(MaLichChieu);
CREATE INDEX IF NOT EXISTS IDX_Ve_MaGhe ON Ve(MaGhe);
CREATE INDEX IF NOT EXISTS IDX_ThanhToan_MaHD ON ThanhToan(MaHD);
CREATE INDEX IF NOT EXISTS IDX_ThanhToan_MaNV ON ThanhToan(MaNV);
CREATE INDEX IF NOT EXISTS IDX_CaLamViec_MaNV_TGBatDau ON CaLamViec(MaNV, TGBatDau);
CREATE INDEX IF NOT EXISTS IDX_LichChieu_TGBatDau ON LichChieu(TGBatDau);
CREATE INDEX IF NOT EXISTS IDX_LichChieu_MaPhim ON LichChieu(MaPhim);
CREATE INDEX IF NOT EXISTS IDX_LichChieu_MaPhong ON LichChieu(MaPhong);
CREATE INDEX IF NOT EXISTS IDX_LichSuDiem_MaKH ON LichSuDiem(MaKH);
CREATE INDEX IF NOT EXISTS IDX_LichSuDiem_MaHD ON LichSuDiem(MaHD);

COMMIT;
