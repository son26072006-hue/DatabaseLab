-- Dùng để tự động xóa bảng cũ
DROP TABLE IF EXISTS CT_HD_SanPham CASCADE;
DROP TABLE IF EXISTS Ve CASCADE;
DROP TABLE IF EXISTS HoaDon CASCADE;
DROP TABLE IF EXISTS LichChieu CASCADE;
DROP TABLE IF EXISTS Ghe CASCADE;
DROP TABLE IF EXISTS SanPham CASCADE;
DROP TABLE IF EXISTS PhongChieu CASCADE;
DROP TABLE IF EXISTS Phim CASCADE;
DROP TABLE IF EXISTS NhanVien CASCADE;
DROP TABLE IF EXISTS KhachHang CASCADE;
-- 1. Bảng Khách hàng
CREATE TABLE KhachHang (
    MaKH SERIAL PRIMARY KEY,
    TenKH VARCHAR(100) NOT NULL,
    SDT VARCHAR(15),
    Email VARCHAR(100),
    NgaySinh DATE,
    DiemTichLuy INT DEFAULT 0,
    HangTVien VARCHAR(50)
);

-- 2. Bảng Nhân viên
CREATE TABLE NhanVien (
    MaNV SERIAL PRIMARY KEY,
    TenNV VARCHAR(100) NOT NULL,
    VaiTro VARCHAR(50),
    SDT VARCHAR(15),
    TaiKhoan VARCHAR(50) UNIQUE,
    MatKhau VARCHAR(255)
);

-- 3. Bảng Phim
CREATE TABLE Phim (
    MaPhim SERIAL PRIMARY KEY,
    TenPhim VARCHAR(255) NOT NULL,
    TheLoai VARCHAR(100),
    ThoiLuong INT, -- Phút
    DoTuoi VARCHAR(10),
    DinhDang VARCHAR(50),
    NgayKC DATE,
    NgayKT DATE
);

-- 4. Bảng Phòng Chiếu
CREATE TABLE PhongChieu (
    MaPhong SERIAL PRIMARY KEY,
    TenPhong VARCHAR(50) NOT NULL,
    LoaiPhong VARCHAR(50),
    SucChua INT
);

-- 5. Bảng Sản phẩm (Bắp, nước...)
CREATE TABLE SanPham (
    MaSP SERIAL PRIMARY KEY,
    TenSP VARCHAR(100) NOT NULL,
    GiaBan DECIMAL(12, 2),
    SoLuongTon INT DEFAULT 0
);
-- 6. Bảng Ghế (Thuộc Phòng Chiếu)
CREATE TABLE Ghe (
    MaGhe SERIAL PRIMARY KEY,
    MaPhong INT REFERENCES PhongChieu(MaPhong) ON DELETE CASCADE,
    TenGhe VARCHAR(10), -- VD: A01, A02
    LoaiGhe VARCHAR(50) -- Thường, VIP, Double
);

-- 7. Bảng Lịch Chiếu
CREATE TABLE LichChieu (
    MaLichChieu SERIAL PRIMARY KEY,
    MaPhim INT REFERENCES Phim(MaPhim),
    MaPhong INT REFERENCES PhongChieu(MaPhong),
    TGBatDau TIMESTAMP NOT NULL,
    TGKetThuc TIMESTAMP NOT NULL
);
-- 8. Bảng Hóa đơn
CREATE TABLE HoaDon (
    MaHD SERIAL PRIMARY KEY,
    MaKH INT REFERENCES KhachHang(MaKH),
    MaNV INT REFERENCES NhanVien(MaNV),
    NgayTao TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    TongTien DECIMAL(12, 2) DEFAULT 0,
    GiamGia DECIMAL(12, 2) DEFAULT 0,
    ThanhTien DECIMAL(12, 2) DEFAULT 0,
    PTThanhToan VARCHAR(50) -- Tiền mặt, Thẻ, Ví điện tử
);

-- 9. Bảng Vé (Chi tiết hóa đơn cho suất chiếu)
CREATE TABLE Ve (
    MaVe SERIAL PRIMARY KEY,
    MaHD INT REFERENCES HoaDon(MaHD) ON DELETE CASCADE,
    MaLichChieu INT REFERENCES LichChieu(MaLichChieu),
    MaGhe INT REFERENCES Ghe(MaGhe),
    GiaVe DECIMAL(12, 2) NOT NULL
);

-- 10. Bảng Chi tiết Hóa đơn Sản phẩm (Composite PK)
CREATE TABLE CT_HD_SanPham (
    MaHD INT REFERENCES HoaDon(MaHD) ON DELETE CASCADE,
    MaSP INT REFERENCES SanPham(MaSP),
    SoLuong INT NOT NULL CHECK (SoLuong > 0),
    DonGia DECIMAL(12, 2) NOT NULL,
    PRIMARY KEY (MaHD, MaSP) -- Composite Primary Key
);
-- Bổ sung cột trạng thái cho bảng Ghế
ALTER TABLE Ghe ADD COLUMN TrangThai VARCHAR(20) DEFAULT 'HoatDong';

-- Bổ sung cột trạng thái cho bảng Hóa Đơn
ALTER TABLE HoaDon ADD COLUMN TrangThaiHD VARCHAR(20) DEFAULT 'ChoThanhToan';
--Ràng buộc duy nhất 
-- 1. Bảng Khách hàng: Số điện thoại và Email không được trùng nhau giữa các khách hàng
ALTER TABLE KhachHang ADD CONSTRAINT UQ_KhachHang_SDT UNIQUE (SDT);
ALTER TABLE KhachHang ADD CONSTRAINT UQ_KhachHang_Email UNIQUE (Email);

-- 2. Bảng Nhân viên: Số điện thoại không được trùng nhau
ALTER TABLE NhanVien ADD CONSTRAINT UQ_NhanVien_SDT UNIQUE (SDT);

-- 3. Bảng Phòng Chiếu: Mỗi phòng chiếu phải có một tên duy nhất để gọi (Rạp 1, Rạp 2, IMAX...)
ALTER TABLE PhongChieu ADD CONSTRAINT UQ_PhongChieu_TenPhong UNIQUE (TenPhong);

-- 4. Bảng Sản phẩm: Tên sản phẩm/combo bắp nước không được trùng lặp
ALTER TABLE SanPham ADD CONSTRAINT UQ_SanPham_TenSP UNIQUE (TenSP);

-- 5. Bảng Ghế: Trong CÙNG MỘT PHÒNG, số ghế không được trùng (Không thể có hai ghế 'A01' trong phòng 1)
ALTER TABLE Ghe ADD CONSTRAINT UQ_Ghe_Phong_TenGhe UNIQUE (MaPhong, TenGhe);

-- 6. Bảng Lịch Chiếu: Một phòng chiếu tại một thời điểm bắt đầu chỉ được có duy nhất 1 suất chiếu
ALTER TABLE LichChieu ADD CONSTRAINT UQ_LichChieu_Phong_ThoiGian UNIQUE (MaPhong, TGBatDau);

-- 7. Bảng Vé (CỰC KỲ QUAN TRỌNG): Chống double-booking. Một chiếc ghế trong một suất chiếu cụ thể chỉ được bán ĐÚNG 1 LẦN.
ALTER TABLE Ve ADD CONSTRAINT UQ_Ve_SuatChieu_Ghe UNIQUE (MaLichChieu, MaGhe);
--Ràng buộc điều kiện 
-- 1. Bảng Khách hàng
-- Ngày sinh phải nằm trong quá khứ
ALTER TABLE KhachHang ADD CONSTRAINT CHK_KhachHang_NgaySinh CHECK (NgaySinh <= CURRENT_DATE);
-- Điểm tích lũy không được phép âm
ALTER TABLE KhachHang ADD CONSTRAINT CHK_KhachHang_Diem CHECK (DiemTichLuy >= 0);
-- Chỉ cho phép 3 hạng thành viên cố định
ALTER TABLE KhachHang ADD CONSTRAINT CHK_KhachHang_HangTVien CHECK (HangTVien IN ('Thuong', 'VIP', 'VVIP'));

-- 2. Bảng Nhân viên
-- Giới hạn đúng các vai trò thực tế của rạp Lotte như trong bối cảnh mô tả
ALTER TABLE NhanVien ADD CONSTRAINT CHK_NhanVien_VaiTro CHECK (VaiTro IN ('Quản lý', 'Bán vé', 'Soát vé', 'Bắp nước', 'Kỹ thuật', 'Vệ sinh', 'Bảo vệ'));

-- 3. Bảng Phim
-- Thời lượng phim (phút) bắt buộc phải lớn hơn 0
ALTER TABLE Phim ADD CONSTRAINT CHK_Phim_ThoiLuong CHECK (ThoiLuong > 0);
-- Ngày kết thúc đợt chiếu phải diễn ra sau hoặc cùng ngày khởi chiếu
ALTER TABLE Phim ADD CONSTRAINT CHK_Phim_NgayChieu CHECK (NgayKT >= NgayKC);
-- Giới hạn định dạng phim theo hạ tầng của rạp
ALTER TABLE Phim ADD CONSTRAINT CHK_Phim_DinhDang CHECK (DinhDang IN ('2D', '3D', 'IMAX', '4DX'));
-- Giới hạn nhãn độ tuổi theo quy định của Cục Điện Ảnh
ALTER TABLE Phim ADD CONSTRAINT CHK_Phim_DoTuoi CHECK (DoTuoi IN ('P', 'K', 'T13', 'T16', 'T18', 'C18'));

-- 4. Bảng Phòng Chiếu
-- Sức chứa của phòng phải lớn hơn 0
ALTER TABLE PhongChieu ADD CONSTRAINT CHK_PhongChieu_SucChua CHECK (SucChua > 0);
-- Phân loại đúng các kiểu phòng đang có tại rạp
ALTER TABLE PhongChieu ADD CONSTRAINT CHK_PhongChieu_LoaiPhong CHECK (LoaiPhong IN ('Standard', 'Gold Class', 'IMAX', '4DX'));

-- 5. Bảng Ghế
-- Loại ghế phải nằm trong danh mục rạp quản lý
ALTER TABLE Ghe ADD CONSTRAINT CHK_Ghe_LoaiGhe CHECK (LoaiGhe IN ('Thường', 'VIP', 'Double'));
-- Trạng thái ghế chỉ có thể là HoatDong hoặc BaoTri
ALTER TABLE Ghe ADD CONSTRAINT CHK_Ghe_TrangThai CHECK (TrangThai IN ('HoatDong', 'BaoTri'));

-- 6. Bảng Lịch Chiếu
-- Thời gian kết thúc suất chiếu bắt buộc phải sau thời gian bắt đầu
ALTER TABLE LichChieu ADD CONSTRAINT CHK_LichChieu_ThoiGian CHECK (TGKetThuc > TGBatDau);

-- 7. Bảng Sản phẩm
-- Giá bán bắp nước không được âm
ALTER TABLE SanPham ADD CONSTRAINT CHK_SanPham_GiaBan CHECK (GiaBan >= 0);
-- Số lượng tồn kho không được âm
ALTER TABLE SanPham ADD CONSTRAINT CHK_SanPham_TonKho CHECK (SoLuongTon >= 0);

-- 8. Bảng Hóa đơn
-- Các trường tiền bạc tuyệt đối không được âm
ALTER TABLE HoaDon ADD CONSTRAINT CHK_HoaDon_TongTien CHECK (TongTien >= 0);
ALTER TABLE HoaDon ADD CONSTRAINT CHK_HoaDon_GiamGia CHECK (GiamGia >= 0);
ALTER TABLE HoaDon ADD CONSTRAINT CHK_HoaDon_ThanhTien CHECK (ThanhTien >= 0);
-- Thanh toán thực tế không được phép vượt quá tổng tiền ban đầu
ALTER TABLE HoaDon ADD CONSTRAINT CHK_HoaDon_LogicTien CHECK (ThanhTien <= TongTien);
-- Giới hạn các phương thức thanh toán mà hệ thống Lotte hỗ trợ
ALTER TABLE HoaDon ADD CONSTRAINT CHK_HoaDon_PTThanhToan CHECK (PTThanhToan IN ('Tiền mặt', 'Thẻ', 'Ví điện tử'));
-- Trạng thái hóa đơn chỉ nhận các giá trị nghiệp vụ quy định
ALTER TABLE HoaDon ADD CONSTRAINT CHK_HoaDon_TrangThaiHD CHECK (TrangThaiHD IN ('ChoThanhToan', 'DaThanhToan', 'DaHuy'));

-- 9. Bảng Vé
-- Giá của một chiếc vé bán ra phải lớn hơn hoặc bằng 0
ALTER TABLE Ve ADD CONSTRAINT CHK_Ve_GiaVe CHECK (GiaVe >= 0);

-- 10. Bảng Chi tiết Hóa đơn Sản phẩm
-- Đơn giá sản phẩm tại thời điểm bán không được âm (Số lượng > 0 bạn đã xử lý ở lệnh CREATE TABLE nên không cần thêm)
ALTER TABLE CT_HD_SanPham ADD CONSTRAINT CHK_CT_HD_SanPham_DonGia CHECK (DonGia >= 0);
--TRIGGER 1 : Kiểm tra chồng chéo lịch chiếu 
CREATE OR REPLACE FUNCTION trg_CheckOverlappingShowtime()
RETURNS TRIGGER AS $$
BEGIN
    -- Kiểm tra xem có suất chiếu nào trùng phòng và đè khung giờ không
    IF EXISTS (
        SELECT 1 FROM LichChieu
        WHERE MaPhong = NEW.MaPhong
          -- Dòng này để bỏ qua chính nó khi bạn thực hiện câu lệnh UPDATE
          AND MaLichChieu <> COALESCE(NEW.MaLichChieu, -1) 
          -- Công thức kiểm tra giao nhau giữa 2 khoảng thời gian
          AND NEW.TGBatDau < TGKetThuc
          AND NEW.TGKetThuc > TGBatDau
    ) THEN
        RAISE EXCEPTION 'LỖI NGHIỆP VỤ: Phòng chiếu (Mã: %) đã có lịch chiếu khác trong khoảng thời gian này!', NEW.MaPhong;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Gắn trigger vào bảng LichChieu (Chạy trước khi INSERT hoặc UPDATE)
CREATE TRIGGER trigger_check_lichchieu
BEFORE INSERT OR UPDATE ON LichChieu
FOR EACH ROW EXECUTE FUNCTION trg_CheckOverlappingShowtime();
--------------------------------------------------------------------------------
-- TRIGGER 2: TỰ ĐỘNG TRỪ KHO BẮP NƯỚC (ĐÃ FIX LỖI "hieutai")
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_UpdateProductStock()
RETURNS TRIGGER AS $$
DECLARE
    v_TonKho INT;
BEGIN
    -- 1. Lấy ra số lượng tồn kho hiện tại của sản phẩm đó
    SELECT SoLuongTon INTO v_TonKho FROM SanPham WHERE MaSP = NEW.MaSP;

    -- 2. Kiểm tra xem kho còn đủ hàng để bán không
    IF v_TonKho < NEW.SoLuong THEN
        RAISE EXCEPTION 'LỖI KHO HÀNG: Sản phẩm (Mã: %) không đủ số lượng trong kho! (Yêu cầu: %, Trong kho còn: %)', 
                        NEW.MaSP, NEW.SoLuong, v_TonKho;
    END IF;

    -- 3. Nếu đủ hàng thì tiến hành trừ kho
    UPDATE SanPham
    SET SoLuongTon = SoLuongTon - NEW.SoLuong
    WHERE MaSP = NEW.MaSP;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Gắn trigger vào bảng CT_HD_SanPham
DROP TRIGGER IF EXISTS trigger_capnhat_kho ON CT_HD_SanPham;
CREATE TRIGGER trigger_capnhat_kho
BEFORE INSERT ON CT_HD_SanPham
FOR EACH ROW EXECUTE FUNCTION trg_UpdateProductStock();


--------------------------------------------------------------------------------
-- TRIGGER 3: TỰ ĐỘNG TÍNH TIỀN HÓA ĐƠN & KHÓA SỬA KHI ĐÃ THANH TOÁN (ĐÃ SỬA LỖI CÚ PHÁP)
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_CalculateInvoiceTotal()
RETURNS TRIGGER AS $$
DECLARE
    v_MaHD INT;
    v_TienVe DECIMAL(12,2) := 0;
    v_TienSP DECIMAL(12,2) := 0;
    v_TongTien DECIMAL(12,2) := 0;
    v_TrangThai VARCHAR(20);
BEGIN
    -- Xác định Mã Hóa Đơn dựa trên hành động (Nếu DELETE thì lấy từ OLD, ngược lại lấy từ NEW)
    IF (TG_OP = 'DELETE') THEN
        v_MaHD := OLD.MaHD;
    ELSE
        v_MaHD := NEW.MaHD;
    END IF;

    -- Kiểm tra trạng thái hóa đơn hiện tại
    SELECT TrangThaiHD INTO v_TrangThai FROM HoaDon WHERE MaHD = v_MaHD;
    IF v_TrangThai = 'DaThanhToan' THEN
        RAISE EXCEPTION 'LỖI BẢO MẬT: Không thể chỉnh sửa nội dung (Vé/Sản phẩm) của hóa đơn đã thanh toán!';
    END IF;

    -- Tính tổng tiền vé hiện có trong hóa đơn
    SELECT COALESCE(SUM(GiaVe), 0) INTO v_TienVe FROM Ve WHERE MaHD = v_MaHD;

    -- Tính tổng tiền bắp nước hiện có trong hóa đơn
    SELECT COALESCE(SUM(SoLuong * DonGia), 0) INTO v_TienSP FROM CT_HD_SanPham WHERE MaHD = v_MaHD;

    v_TongTien := v_TienVe + v_TienSP;

    -- Cập nhật ngược lại vào bảng HoaDon
    UPDATE HoaDon
    SET TongTien = v_TongTien,
        ThanhTien = GREATEST(v_TongTien - GiamGia, 0)
    WHERE MaHD = v_MaHD;

    IF (TG_OP = 'DELETE') THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Gắn trigger vào bảng Vé
DROP TRIGGER IF EXISTS trigger_tinhtien_ve ON Ve;
CREATE TRIGGER trigger_tinhtien_ve
AFTER INSERT OR UPDATE OR DELETE ON Ve
FOR EACH ROW EXECUTE FUNCTION trg_CalculateInvoiceTotal();

-- Gắn trigger vào bảng Chi tiết Sản phẩm
DROP TRIGGER IF EXISTS trigger_tinhtien_sp ON CT_HD_SanPham;
CREATE TRIGGER trigger_tinhtien_sp
AFTER INSERT OR UPDATE OR DELETE ON CT_HD_SanPham
FOR EACH ROW EXECUTE FUNCTION trg_CalculateInvoiceTotal();