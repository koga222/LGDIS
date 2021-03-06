# encoding: utf-8
require 'csv'
class Shelter < ActiveRecord::Base
  unloadable
  
  attr_accessible :name,:name_kana,:area,:address,:phone,:fax,:e_mail,:person_responsible,
                  :shelter_type,:shelter_type_detail,:shelter_sort,:opened_at,
                  :closed_at,:capacity,:status,:head_count_voluntary,
                  :households_voluntary,:checked_at,:manager_code,:manager_name,
                  :manager_another_name,:reported_at,:building_damage_info,
                  :electric_infra_damage_info,:communication_infra_damage_info,
                  :other_damage_info,:usable_flag,:openable_flag,:note,
                  :head_count, :households,:injury_count, :upper_care_level_three_count,
                  :elderly_alone_count, :elderly_couple_count, :bedridden_elderly_count,
                  :elderly_dementia_count, :rehabilitation_certificate_count, :physical_disability_certificate_count,
                  :created_by, :updated_by,
                  :as => :shelter
  
  attr_accessible :head_count,:households,:injury_count,:upper_care_level_three_count,
                  :elderly_alone_count,:elderly_couple_count,:bedridden_elderly_count,
                  :elderly_dementia_count,:rehabilitation_certificate_count,
                  :physical_disability_certificate_count, :updated_by,
                  :as => :count
  
  # 正の整数チェック用オプションハッシュ値
  POSITIVE_INTEGER = {:only_integer => true,
                      :greater_than_or_equal_to => 0,
                      :less_than_or_equal_to => 2147483647,
                      :allow_blank => true}.freeze
  
  # コンスタント存在チェック用
  CONST = Constant::hash_for_table(self.table_name).freeze
  
  acts_as_paranoid
  validates_as_paranoid
  acts_as_mode_switchable Project
  
  validates :name, :presence => true,
                :length => {:maximum => 30}
  validates_uniqueness_of_without_deleted :name, :scope => :record_mode
  validates :name_kana,
                :length => {:maximum => 60}
  validates :area, :presence => true
  validates :address, :presence => true, 
                :length => {:maximum => 200}
  validates :phone,
                :length => {:maximum => 20},
                :custom_format => {:type => :phone_number}
  validates :fax,
                :length => {:maximum => 20},
                :custom_format => {:type => :phone_number}
  validates :e_mail,
                :length => {:maximum => 255},
                :custom_format => {:type => :mail_address}
  validates :person_responsible,
                :length => {:maximum => 100}
  validates :shelter_type, :presence => true,
                :inclusion => {:in => CONST[:shelter_type.to_s].keys, :allow_blank => true}
  validates :shelter_type_detail,
                :length => {:maximum => 255}
  validates :shelter_sort, :presence => true,
                :inclusion => {:in => CONST[:shelter_sort.to_s].keys, :allow_blank => true}
  validates :opened_at,
                :custom_format => {:type => :datetime}
  validates :closed_at,
                :custom_format => {:type => :datetime}
  validates :capacity,
                :numericality => POSITIVE_INTEGER
  validates :status,
                :inclusion => {:in => CONST[:status.to_s].keys, :allow_blank => true}
  validates :head_count,
                :numericality => POSITIVE_INTEGER
  validates :head_count_voluntary,
                :numericality => POSITIVE_INTEGER
  validates :households,
                :numericality => POSITIVE_INTEGER
  validates :households_voluntary,
                :numericality => POSITIVE_INTEGER
  validates :checked_at,
                :custom_format => {:type => :datetime}
  validates :manager_code,
                :length => {:maximum => 10}
  validates :manager_name,
                :length => {:maximum => 100}
  validates :manager_another_name,
                :length => {:maximum => 100}
  validates :reported_at,
                :custom_format => {:type => :datetime}
  validates :building_damage_info,
                :length => {:maximum => 4000}
  validates :electric_infra_damage_info,
                :length => {:maximum => 4000}
  validates :communication_infra_damage_info,
                :length => {:maximum => 4000}
  validates :other_damage_info,
                :length => {:maximum => 4000}
  validates :usable_flag,
                :inclusion => {:in => CONST[:usable_flag.to_s].keys, :allow_blank => true}
  validates :openable_flag,
                :inclusion => {:in => CONST[:openable_flag.to_s].keys, :allow_blank => true}
  validates :injury_count,
                :numericality => POSITIVE_INTEGER
  validates :upper_care_level_three_count,
                :numericality => POSITIVE_INTEGER
  validates :elderly_alone_count,
                :numericality => POSITIVE_INTEGER
  validates :elderly_couple_count,
                :numericality => POSITIVE_INTEGER
  validates :bedridden_elderly_count,
                :numericality => POSITIVE_INTEGER
  validates :elderly_dementia_count,
                :numericality => POSITIVE_INTEGER
  validates :rehabilitation_certificate_count,
                :numericality => POSITIVE_INTEGER
  validates :physical_disability_certificate_count,
                :numericality => POSITIVE_INTEGER
  validates :note,
                :length => {:maximum => 4000}
  validates :created_by,
                :length => {:maximum => 255}
  validates :updated_by,
                :length => {:maximum => 255}
  
  before_create :number_shelter_code, :if => Proc.new { |shelter| shelter.shelter_code.nil? }
  after_save :execute_release_all_data
  after_destroy :execute_release_all_data
  
  # 属性のローカライズ名取得
  # validateエラー時のメッセージに使用されます。
  # "field_" + 属性名 でローカライズします。
  # モデル名の複数系をスコープに設定してローカライズできない場合は、スコープ無しのローカライズ結果を返却します。
  # ==== Args
  # _attr_ :: 属性名
  # _args_ :: args
  # ==== Return
  # 項目名
  # ==== Raise
  def self.human_attribute_name(attr, *args)
    begin
      localized = l("field_#{name.underscore.gsub('/', '_')}_#{attr}",
                    :scope => self.name.underscore.pluralize,
                    :default => ["field_#{attr}".to_sym, attr],
                    :raise => true)
    rescue
    end
    localized ||= l("field_#{name.underscore.gsub('/', '_')}_#{attr}",
                    :default => ["field_#{attr}".to_sym, attr])
  end
  
  # チケット登録処理
  # ==== Args
  # _project_ :: Projectオブジェクト
  # _options_ :: チケット情報
  # ==== Return
  # Issueオブジェクト配列
  # ==== Raise
  def self.create_issues(project, options)
    issues = []
    ### 公共コモンズ用チケット登録
    issues << self.create_commons_issue(project, options)
    ### Applic用チケット登録
#     issues << self.create_applic_issue(project)
    return issues
  end
  
  # Applic用チケット登録処理
  # ==== Args
  # _project_ :: Projectオブジェクト
  # ==== Return
  # Issueオブジェクト
  # ==== Raise
  def self.create_applic_issue(project)
    doc =  REXML::Document.new
    doc << REXML::XMLDecl.new('1.0', 'UTF-8')
    doc.add_element("_避難所") # Root
    
    # 避難所を取得しXMLを生成する
    shelters = Shelter.mode_in(project).all.each do |shelter|
      node_shelter = doc.root.add_element("_避難所情報")
      
      node_shelter.add_element("災害識別情報").add_text("#{project.disaster_code}")
      node_shelter.add_element("災害名").add_text("#{project.name}")
      node_shelter.add_element("都道府県").add_text("")
      node_shelter.add_element("市町村_消防本部名").add_text("")
      node_shelter.add_element("避難所識別情報").add_text("#{shelter.shelter_code}")
      node_shelter.add_element("避難所名").add_text("#{shelter.name}")
      node_shelter.add_element("電話番号").add_text("#{shelter.phone}")
      node_shelter.add_element("FAX番号").add_text("#{shelter.fax}")
      
      node_manager = node_shelter.add_element("管理者")
      node_manager.add_element("職員番号").add_text("#{shelter.manager_code}")
      node_name = node_manager.add_element("氏名")
      node_name.add_element("外字氏名").add_text("")
      node_name.add_element("内字氏名").add_text("#{shelter.manager_name}")
      node_name.add_element("フリガナ").add_text("")
      node_staff = node_manager.add_element("職員別名称")
      node_staff.add_element("外字氏名").add_text("")
      node_staff.add_element("内字氏名").add_text("")
      node_staff.add_element("フリガナ").add_text("")
      
      node_shelter.add_element("収容人数").add_text("#{shelter.capacity}")
      
      node_report = node_shelter.add_element("報告日時")
      node_report_date = node_report.add_element("日付")
      node_report_date.add_element("年").add_text("#{shelter.reported_at.try(:year)}")
      node_report_date.add_element("月").add_text("#{shelter.reported_at.try(:month)}")
      node_report_date.add_element("日").add_text("#{shelter.reported_at.try(:day)}")
      node_report.add_element("時").add_text("#{shelter.reported_at.try(:hour)}")
      node_report.add_element("分").add_text("#{shelter.reported_at.try(:min)}")
      node_report.add_element("秒").add_text("#{shelter.reported_at.try(:sec)}")
      
      node_shelter.add_element("建物被害状況").add_text("#{shelter.building_damage_info}")
      node_shelter.add_element("電力被害状況").add_text("#{shelter.electric_infra_damage_info}")
      node_shelter.add_element("通信手段被害状況").add_text("#{shelter.communication_infra_damage_info}")
      node_shelter.add_element("その他の被害").add_text("#{shelter.other_damage_info}")
      node_shelter.add_element("使用可否").add_text("#{CONST['usable_flag'][shelter.usable_flag]}")
      node_shelter.add_element("開設の可否").add_text("#{CONST['openable_flag'][shelter.openable_flag]}")
      
      node_opened = node_shelter.add_element("開設日時")
      node_opened_date = node_opened.add_element("日付")
      node_opened_date.add_element("年").add_text("#{shelter.opened_at.try(:year)}")
      node_opened_date.add_element("月").add_text("#{shelter.opened_at.try(:month)}")
      node_opened_date.add_element("日").add_text("#{shelter.opened_at.try(:day)}")
      node_opened.add_element("時").add_text("#{shelter.opened_at.try(:hour)}")
      node_opened.add_element("分").add_text("#{shelter.opened_at.try(:min)}")
      node_opened.add_element("秒").add_text("#{shelter.opened_at.try(:sec)}")
      
      node_closed = node_shelter.add_element("閉鎖日時")
      node_closed_date = node_closed.add_element("日付")
      node_closed_date.add_element("年").add_text("#{shelter.closed_at.try(:year)}")
      node_closed_date.add_element("月").add_text("#{shelter.closed_at.try(:month)}")
      node_closed_date.add_element("日").add_text("#{shelter.closed_at.try(:day)}")
      node_closed.add_element("時").add_text("#{shelter.closed_at.try(:hour)}")
      node_closed.add_element("分").add_text("#{shelter.closed_at.try(:min)}")
      node_closed.add_element("秒").add_text("#{shelter.closed_at.try(:sec)}")
      
      node_shelter.add_element("避難者数").add_text("#{shelter.head_count}")
      node_shelter.add_element("避難世帯数").add_text("#{shelter.households}")
      node_shelter.add_element("負傷者数").add_text("#{shelter.injury_count}")
      
      node_aid = node_shelter.add_element("要援護者数")
      node_aid.add_element("要介護度3以上").add_text("#{shelter.upper_care_level_three_count}")
      node_aid.add_element("一人暮らし高齢者_65歳以上").add_text("#{shelter.elderly_alone_count}")
      node_aid.add_element("高齢者世帯_夫婦共に65歳以上").add_text("#{shelter.elderly_couple_count}")
      node_aid.add_element("寝たきり高齢者").add_text("#{shelter.bedridden_elderly_count}")
      node_aid.add_element("認知症高齢者").add_text("#{shelter.elderly_dementia_count}")
      node_aid.add_element("療育手帳A_A1_A2所持者").add_text("#{shelter.rehabilitation_certificate_count}")
      node_aid.add_element("身体障がい者手帳1_2級所持者").add_text("#{shelter.physical_disability_certificate_count}")
      
      node_shelter.add_element("備考").add_text("#{shelter.note}")
    end
    
    issue = Issue.new
    issue.tracker_id = 31
    issue.project_id = project.id
    issue.subject    = "避難所情報 #{Time.now.strftime("%Y/%m/%d %H:%M:%S")}"
    issue.author_id  = User.current.id
    issue.xml_body   = doc.to_s
    issue.save!
    
    return issue
  end
  
  # 公共コモンズ用チケット登録処理
  # ==== Args
  # _project_ :: Projectオブジェクト
  # _options_ :: チケット情報
  # ==== Return
  # Issueオブジェクト
  # ==== Raise
  def self.create_commons_issue(project, options)
    # Xmlドキュメントの生成
    doc  = REXML::Document.new
    
    # 避難人数、避難世帯数の集計値および避難所件数の取得
    summary  = Shelter.mode_in(project).select("SUM(head_count) AS head_count_sum, SUM(head_count_voluntary) AS head_count_voluntary_sum,
      SUM(households) AS households_sum, SUM(households_voluntary) AS households_voluntary_sum, COUNT(*) AS count").where(:shelter_sort => ["2","5"]).first
    
    # Shelter要素の追加
    node_shelter = doc.add_element("pcx_sh:Shelter") # Root
    
    node_disaster = node_shelter.add_element("pcx_eb:Disaster")
    node_disaster.add_element("pcx_eb:DisasterName").add_text("#{project.name}")
    node_shelter.add_element("pcx_sh:ComplementaryInfo")
    
    # 子要素がすべてブランクの場合、親要素を生成しない
    if summary.head_count_sum.present? || summary.head_count_voluntary_sum.present? ||
      summary.households_sum.present? || summary.households_voluntary_sum.present?
      # 親要素の追加
      node_total_number = node_shelter.add_element("pcx_sh:TotalNumber")
      # 避難総人数 自主避難人数を含む。
      node_total_number.add_element("pcx_sh:HeadCount").add_text("#{summary.head_count_sum}") if summary.head_count_sum.present?
      # 避難総人数（うち自主避難）
      node_total_number.add_element("pcx_sh:HeadCountVoluntary").add_text("#{summary.head_count_voluntary_sum}") if summary.head_count_voluntary_sum.present?
      # 避難総世帯数
      node_total_number.add_element("pcx_sh:Households").add_text("#{summary.households_sum}") if summary.households_sum.present?
      # 避難総世帯数（うち自主避難）
      node_total_number.add_element("pcx_sh:HouseholdsVoluntary").add_text("#{summary.households_voluntary_sum}") if summary.households_voluntary_sum.present?
    end
    
    # 開設避難所数
    node_shelter.add_element("pcx_sh:TotalNumberOfShelter").add_text("#{summary.count}") if summary.count.present?
    # ループ構造の親要素追加
    node_informations = node_shelter.add_element("pcx_sh:Informations")
    
    # 避難所を取得しXMLを生成する
    @shelters = Shelter.mode_in(project).order(:shelter_code)
    @shelters.each do |shelter|
      node_information = node_informations.add_element("pcx_sh:Information")
      
      # 子要素がすべてブランクの場合、親要素を生成しない
      if shelter.name.present? || shelter.name_kana.present? ||
        shelter.phone.present? || shelter.address.present? ||
        shelter.fax.present? || shelter.e_mail.present? ||
        shelter.person_responsible.present?
        # 親要素の追加
        node_location = node_information.add_element("pcx_sh:Location")
        # 所在地（緯度・経度）
        # node_location.add_element("edxlde:circle").add_text("")
        # 避難所名
        node_location.add_element("commons:areaName").add_text("#{shelter.name}") if shelter.name.present?
        # 避難所名ふりがな
        node_location.add_element("commons:areaNameKana").add_text("#{shelter.name_kana}") if shelter.name_kana.present?
        # 避難所連絡先
        node_location.add_element("pcx_eb:ContactInfo", {"pcx_eb:contactType" => "phone"}).add_text("#{shelter.phone}") if shelter.phone.present?
        # 避難所のFAX番号
        node_location.add_element("pcx_eb:ContactInfo", {"pcx_eb:contactType" => "fax"}).add_text("#{shelter.fax}") if shelter.fax.present?
        # 避難所のメールアドレス
        node_location.add_element("pcx_eb:ContactInfo", {"pcx_eb:contactType" => "e-mail"}).add_text("#{shelter.e_mail}") if shelter.e_mail.present?
        # 避難所の担当者名
        node_location.add_element("pcx_eb:ContactInfo", {"pcx_eb:contactType" => "personResponsible"}).add_text("#{shelter.person_responsible}") if shelter.person_responsible.present?
        # 所在地
        node_location.add_element("pcx_sh:Address").add_text("#{shelter.address}") if shelter.address.present?
      end
      
      # 避難所種別 "避難所","臨時避難所","広域避難場所","一時避難場所"
      node_information.add_element("pcx_sh:Type").add_text(CONST["shelter_type"]["#{shelter.shelter_type}"]) if shelter.shelter_type.present?
      # 開設状況 "未開設","開設","閉鎖","不明","常設"
      node_information.add_element("pcx_sh:Sort").add_text(CONST["shelter_sort"]["#{shelter.shelter_sort}"]) if shelter.shelter_sort.present?
      # 避難所種別で表現しきれない情報
      node_information.add_element("pcx_sh:TypeDetail").add_text("#{shelter.shelter_type_detail}") if shelter.shelter_type_detail.present?
      
      # 開設・閉鎖日時
      case shelter.shelter_sort
      when "1" # 未開設
        date = nil
      when "2" # 開設
        date = shelter.opened_at.xmlschema if shelter.opened_at.present?
      when "3" # 閉鎖
        date = shelter.closed_at.xmlschema if shelter.closed_at.present?
      when "4" # 不明
        date = nil
      when "5" # 常設
        date = nil
      else
        date = nil
      end
      node_information.add_element("pcx_sh:DateTime").add_text("#{date}") if date.present?
      # 最大収容人数 不明の場合は要素を省略
      node_information.add_element("pcx_sh:Capacity").add_text("#{shelter.capacity}") if shelter.capacity.present?
      # 避難所状況 "空き","混雑","定員一杯","不明"
      node_information.add_element("pcx_sh:Status").add_text("#{CONST['status'][shelter.status]}") if shelter.status.present?
      
      # 子要素がすべてブランクの場合、親要素を生成しない
      if shelter.head_count.present? || shelter.head_count_voluntary.present? ||
        shelter.households.present? || shelter.households_voluntary.present?
        # 親要素の追加
        node_number_of = node_information.add_element("pcx_sh:NumberOf")
        # 避難人数 自主避難人数を含む。不明の場合は要素を省略。
        node_number_of.add_element("pcx_sh:HeadCount").add_text("#{shelter.head_count}") if shelter.head_count.present?
        # 避難人数（うち自主避難）不明の場合は要素を省略。
        node_number_of.add_element("pcx_sh:HeadCountVoluntary").add_text("#{shelter.head_count_voluntary}") if shelter.head_count_voluntary.present?
        # 避難世帯数 自主避難人数を含む。不明の場合は要素を省略。
        node_number_of.add_element("pcx_sh:Households", {"pcx_sh:unit" => "世帯"}).add_text("#{shelter.households}") if shelter.households.present?
        # 避難世帯数（うち自主避難）
        node_number_of.add_element("pcx_sh:HouseholdsVoluntary", {"pcx_sh:unit" => "世帯"}).add_text("#{shelter.households_voluntary}") if shelter.households_voluntary.present?
      end
      
      # 避難所状況確認日時
      node_information.add_element("pcx_sh:CheckedDateTime").add_text("#{shelter.checked_at.xmlschema}") if shelter.checked_at.present?
    end
    
    issue = Issue.new
    issue.tracker_id = 2
    issue.project_id = project.id
    issue.subject    = "避難所情報 #{Time.now.strftime("%Y/%m/%d %H:%M:%S")}"
    issue.author_id  = User.current.id
    issue.xml_body   = doc.to_s
    # チケットにcsvファイルを添付する
    tf = create_csv(@shelters, "避難所情報", [:name,:name_kana,:area,:address,:phone,:fax,:e_mail,:person_responsible,
      :shelter_type,:shelter_type_detail,:shelter_sort,:opened_at,:closed_at,:capacity,:status,:head_count]) do |key, value|
      if key == "area"
        Area.all.select{|v| v.area_code == value}.first.try(:name)
      else
        value
      end
    end
    issue.save_attachments(["file"=> tf, "description" => "全ての避難所情報CSVファイル ※チケット作成時点"])
    # 一時ファイルの削除
    tf.close(true)
    
    issue.description = options[:description]
    issue.save!
    
    return issue
  end
  
  # 全データ公開処理を行います。
  # JSONファイルを上書きします。
  # ==== Args
  # ==== Return
  # ==== Raise
  def self.release_all_data
    create_json_file
  end
  
  # JSONファイルを上書きします。
  # ==== Args
  # ==== Return
  # ==== Raise
  def self.create_json_file
    h = {}
    Shelter.all.each do |s|
      h[s.shelter_code] = s.name
    end
    File.open(File.join(Rails.root,"public","shelter.json"), "w:utf-8") do |f|
      f.write(JSON.generate(h))
    end
  end
  
  # 全データ公開処理を呼び出します。（コールバック向け）
  # ==== Args
  # ==== Return
  # ==== Raise
  def execute_release_all_data
    self.class.release_all_data
  end
  
  # 後続処理で登録するチケットの説明文を作成
  # ==== Args
  # _target_selves_ :: 更新対象
  # ==== Return
  # 公共コモンズ用チケットの説明フィールドに入力する文言
  # ==== Raise
  def self.get_description(target_selves)
    description = []
    target_selves.each do |shelter|
      description << "|#{[shelter.name, CONST[:shelter_type.to_s][shelter.shelter_type], CONST[:shelter_sort.to_s][shelter.shelter_sort]].join("|")}|"
    end
    return description.compact.join("\n")
  end
  
  private
  
  # 避難所識別番号を設定します。
  # ==== Args
  # ==== Return
  # ==== Raise
  def number_shelter_code
    seq =  connection.select_value("select nextval('shelter_code_seq')")
    self.shelter_code = "04202I#{format("%014d", seq)}"
  end
end
