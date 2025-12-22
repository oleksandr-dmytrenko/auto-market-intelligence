"""
IAAI parser - парсинг HTML страниц IAAI.com
"""
from bs4 import BeautifulSoup
from typing import List, Dict, Optional
import re
import time

class IAAIParser:
    """Парсер для IAAI.com"""
    
    BASE_URL = 'https://www.iaai.com'
    
    @staticmethod
    def build_search_url(make: str = None, model: str = None, from_year: int = None, to_year: int = None, page: int = 1) -> str:
        """
        Строит URL для поиска на IAAI
        
        Пример: https://www.iaai.com/Vehicles?make=Audi&model=Q5&yearFrom=2021&yearTo=2023&page=1
        """
        params = []
        
        if make:
            params.append(f"make={make}")
        if model:
            params.append(f"model={model}")
        if from_year:
            params.append(f"yearFrom={from_year}")
        if to_year:
            params.append(f"yearTo={to_year}")
        
        # Добавляем пагинацию
        if page > 1:
            params.append(f"page={page}")
        
        query_string = "&".join(params)
        if query_string:
            return f"{IAAIParser.BASE_URL}/Vehicles?{query_string}"
        else:
            return f"{IAAIParser.BASE_URL}/Vehicles"
    
    @staticmethod
    def build_all_vehicles_url(page: int = 1) -> str:
        """
        Строит URL для получения всех автомобилей (без фильтров)
        Использует правильный формат поиска: /Search?url=...
        
        Args:
            page: Номер страницы (начинается с 1)
        """
        # Используем правильный формат поиска (пример из пользователя)
        # Для первой страницы используем базовый URL поиска
        if page == 1:
            # Базовый URL для поиска всех автомобилей
            # В будущем можно генерировать правильный url параметр
            return f"{IAAIParser.BASE_URL}/Search?url=3BICQIt4iWsDWssKFw7x37aBx8b1d992udS%2bPhsBGPo%3d"
        else:
            # Для последующих страниц добавляем параметр page
            return f"{IAAIParser.BASE_URL}/Search?url=3BICQIt4iWsDWssKFw7x37aBx8b1d992udS%2bPhsBGPo%3d&page={page}"
    
    @staticmethod
    def parse_listing_page(html: str) -> List[Dict]:
        """
        Парсит страницу со списком результатов
        
        Возвращает список словарей с базовой информацией о каждом автомобиле
        """
        soup = BeautifulSoup(html, 'html.parser')
        listings = []
        seen_urls = set()
        
        # Стратегия 1: Ищем ссылки на детальные страницы по различным паттернам
        # IAAI использует формат: /VehicleDetail/ID~COUNTRY (например: /VehicleDetail/44335311~US)
        link_patterns = [
            r'/VehicleDetail/',  # Основной формат: /VehicleDetail/44335311~US
            r'/Vehicle/',
            r'/Lot/',
            r'/Detail/',
            r'/vehicles/',
            r'/vehicle/',
            r'/lot/',
            r'/detail/',
            r'/auction/',
            r'/item/',
        ]
        
        # Исключаем служебные домены и пути
        excluded_domains = ['help', 'support', 'about', 'contact', 'careers', 'blog', 'news', 
                           'terms', 'privacy', 'legal', 'faq', 'login', 'register', 'account',
                           'cart', 'checkout', 'search', 'filter', 'sort']
        excluded_paths = ['/help', '/support', '/about', '/contact', '/careers', '/blog', 
                         '/news', '/terms', '/privacy', '/legal', '/faq', '/login', '/register',
                         '/account', '/cart', '/checkout', '/search', '/filter', '/sort', '/s/']
        
        # Ищем все ссылки, которые могут быть ссылками на детальные страницы
        all_links = soup.find_all('a', href=True)
        print(f"  Debug: Found {len(all_links)} total links on page")
        
        for link in all_links:
            href = link.get('href', '')
            if not href:
                continue
            
            href_lower = href.lower()
            
            # СТРОГАЯ проверка внешних доменов ДО нормализации
            if href.startswith('http'):
                # Пропускаем все внешние домены (не iaai.com)
                if not re.match(r'https?://(www\.)?iaai\.com', href_lower):
                    continue
                # Пропускаем поддомены help, support и т.д.
                if re.match(r'https?://(help|support|about|contact|careers|blog|news|itunes|apple|google|facebook)\.', href_lower):
                    continue
                # Пропускаем если содержит внешние домены в пути
                if re.search(r'itunes\.|apple\.|google\.|facebook\.|twitter\.|youtube\.', href_lower):
                    continue
            
            # Пропускаем служебные ссылки ДО нормализации
            if any(excluded in href_lower for excluded in excluded_domains):
                continue
            if any(href_lower.startswith(path) or path in href_lower for path in excluded_paths):
                continue
            
            # Пропускаем якорные ссылки и javascript
            if href.startswith('#') or href.startswith('javascript:'):
                continue
            
            # Проверяем, соответствует ли ссылка паттернам детальных страниц
            matches_pattern = any(re.search(pattern, href, re.I) for pattern in link_patterns)
            
            # Также проверяем, содержит ли ссылка ID (цифры) и находится на основном домене
            has_id = bool(re.search(r'/\d+', href))
            is_main_domain = 'iaai.com' in href_lower and 'help' not in href_lower and 'support' not in href_lower
            
            # Приоритет для /VehicleDetail/ - это основной формат
            is_vehicle_detail = '/VehicleDetail/' in href or '/vehicledetail/' in href_lower
            
            if is_vehicle_detail or (matches_pattern or (has_id and is_main_domain)) and ('vehicle' in href_lower or 'lot' in href_lower or 'detail' in href_lower or has_id):
                # Нормализуем URL
                if not href.startswith('http'):
                    if href.startswith('/'):
                        href = IAAIParser.BASE_URL + href
                    else:
                        href = IAAIParser.BASE_URL + '/' + href
                
                # Финальная проверка: только www.iaai.com (не поддомены)
                href_normalized = href.lower()
                if not re.match(r'https?://(www\.)?iaai\.com/', href_normalized):
                    continue
                
                # Пропускаем если содержит служебные пути даже после нормализации
                if any(excluded in href_normalized for excluded in ['/help', '/support', '/about', '/contact', '/s/']):
                    continue
                
                # Убираем query параметры для source_id
                clean_href = href.split('?')[0]
                
                if clean_href in seen_urls:
                    continue
                
                # Извлекаем source_id ДО добавления в seen_urls
                # Также пробуем извлечь из атрибутов name или id ссылки
                source_id = IAAIParser._extract_source_id(clean_href)
                
                # Если не нашли в URL, пробуем из атрибутов ссылки
                if not source_id or len(source_id) < 3:
                    # Пробуем извлечь из атрибута name (например: name="44335311")
                    name_attr = link.get('name', '')
                    if name_attr and re.match(r'^\d+$', name_attr) and len(name_attr) >= 4:
                        source_id = name_attr
                    else:
                        # Пробуем из атрибута id (например: id="a+44335311")
                        id_attr = link.get('id', '')
                        if id_attr:
                            id_match = re.search(r'(\d{4,})', id_attr)
                            if id_match:
                                source_id = id_match.group(1)
                
                # Пропускаем если source_id не найден или слишком короткий (меньше 4 символов)
                # Это исключит служебные ссылки типа /s/, /help и т.д.
                if not source_id or len(source_id) < 4 or not re.match(r'^\d+$', source_id):
                    continue
                
                # Проверяем, что URL действительно содержит этот ID
                if source_id not in clean_href:
                    continue
                
                seen_urls.add(clean_href)
                
                listing_data = {
                    'detail_url': clean_href,
                    'source_id': source_id,
                    'raw_title': link.get_text(strip=True) or 'No title'
                }
                listings.append(listing_data)
        
        # Стратегия 2: Ищем контейнеры с результатами по классам
        if not listings:
            listing_items = soup.find_all(['div', 'article', 'li', 'tr'], 
                                         class_=re.compile(r'vehicle|listing|item|result|lot|card|row', re.I))
            print(f"  Debug: Found {len(listing_items)} items by class patterns")
            
            for item in listing_items:
                try:
                    # Ищем ссылку внутри элемента
                    link = item.find('a', href=True)
                    if not link:
                        continue
                    
                    href = link.get('href', '')
                    if not href:
                        continue
                    
                    if not href.startswith('http'):
                        if href.startswith('/'):
                            href = IAAIParser.BASE_URL + href
                        else:
                            href = IAAIParser.BASE_URL + '/' + href
                    
                    clean_href = href.split('?')[0]
                    if clean_href in seen_urls:
                        continue
                    seen_urls.add(clean_href)
                    
                    listing_data = {
                        'detail_url': clean_href,
                        'source_id': IAAIParser._extract_source_id(clean_href),
                        'raw_title': link.get_text(strip=True) or item.get_text(strip=True)[:100]
                    }
                    listings.append(listing_data)
                except Exception as e:
                    print(f"  Debug: Error parsing item: {e}")
                    continue
        
        # Стратегия 3: Ищем data-атрибуты с ID или URL
        if not listings:
            items_with_data = soup.find_all(attrs={'data-vehicle-id': True})
            items_with_data.extend(soup.find_all(attrs={'data-lot-id': True}))
            items_with_data.extend(soup.find_all(attrs={'data-id': True}))
            print(f"  Debug: Found {len(items_with_data)} items with data attributes")
            
            for item in items_with_data:
                try:
                    vehicle_id = item.get('data-vehicle-id') or item.get('data-lot-id') or item.get('data-id')
                    if vehicle_id:
                        # Пробуем построить URL
                        possible_urls = [
                            f"{IAAIParser.BASE_URL}/Vehicle/{vehicle_id}",
                            f"{IAAIParser.BASE_URL}/Lot/{vehicle_id}",
                            f"{IAAIParser.BASE_URL}/vehicles/{vehicle_id}",
                        ]
                        
                        for url in possible_urls:
                            if url not in seen_urls:
                                seen_urls.add(url)
                                listing_data = {
                                    'detail_url': url,
                                    'source_id': str(vehicle_id),
                                    'raw_title': item.get_text(strip=True)[:100] or 'No title'
                                }
                                listings.append(listing_data)
                                break
                except Exception as e:
                    print(f"  Debug: Error parsing data attribute item: {e}")
                    continue
        
        # Финальная фильтрация: убираем все ссылки без валидного source_id
        valid_listings = []
        for listing in listings:
            source_id = listing.get('source_id', '')
            url = listing.get('detail_url', '')
            
            # Пропускаем если source_id пустой или слишком короткий (минимум 2 символа)
            if not source_id or len(source_id) < 2:
                continue
            
            # Если source_id не число, но содержит цифры, пробуем извлечь число
            if not re.match(r'^\d+$', source_id):
                # Пробуем найти число в source_id
                number_match = re.search(r'\d+', source_id)
                if number_match and len(number_match.group()) >= 4:
                    source_id = number_match.group()
                else:
                    continue
            
            # Пропускаем служебные URL
            url_lower = url.lower()
            
            # СТРОГАЯ проверка домена в финальной фильтрации
            if not re.match(r'https?://(www\.)?iaai\.com', url_lower):
                continue
            
            # Пропускаем внешние домены
            if re.search(r'itunes\.|apple\.|google\.|facebook\.|twitter\.|youtube\.|amazon\.', url_lower):
                continue
            
            if any(excluded in url_lower for excluded in ['help', 'support', '/s/', '/about', '/contact', '/app/']):
                continue
            
            # Проверяем, что URL содержит source_id
            if source_id not in url:
                continue
            
            valid_listings.append(listing)
        
        print(f"  Debug: Total listings found: {len(listings)}, valid: {len(valid_listings)}")
        return valid_listings
    
    @staticmethod
    def _parse_listing_item(item, href: str) -> Optional[Dict]:
        """Парсит один элемент из списка результатов"""
        link = item.find('a', href=re.compile(r'/Vehicle/|/Lot/|/Detail/', re.I))
        if not link:
            return None
        
        # Извлекаем базовую информацию
        text = link.get_text(strip=True)
        if not text:
            text = item.get_text(strip=True)
        
        return {
            'detail_url': href,
            'source_id': IAAIParser._extract_source_id(href),
            'raw_title': text
        }
    
    @staticmethod
    def parse_detail_page(html: str, detail_url: str) -> Dict:
        """
        Парсит детальную страницу автомобиля
        
        Извлекает все данные: make, model, year, mileage, price, damage, location, VIN, фото
        """
        soup = BeautifulSoup(html, 'html.parser')
        
        source_id = IAAIParser._extract_source_id(detail_url)
        data = {
            'source': 'iaai',
            'source_id': source_id,
            'lot_id': source_id,  # lot_id совпадает с source_id для IAAI
            'auction_url': detail_url,
            'auction_status': 'active',  # IAAI обычно показывает активные аукционы
            'raw_data': {}
        }
        
        # Извлекаем Stock #
        stock_number = IAAIParser._extract_stock_number(soup)
        if stock_number:
            data['stock_number'] = stock_number
            data['raw_data']['stock_number'] = stock_number
        
        # Извлекаем VIN (полный или partial)
        vin = IAAIParser._extract_vin(soup)
        if vin:
            data['vin'] = vin
            data['raw_data']['vin'] = vin
        
        # Извлекаем partial VIN отдельно
        partial_vin = IAAIParser._extract_partial_vin(soup)
        if partial_vin:
            data['partial_vin'] = partial_vin
            data['raw_data']['partial_vin'] = partial_vin
        elif vin and len(vin) >= 11:
            # Если есть полный VIN, извлекаем partial из него
            data['partial_vin'] = vin[0:13]
        
        # Извлекаем заголовок (обычно содержит make, model, year)
        title = IAAIParser._extract_title(soup)
        if title:
            make, model, year = IAAIParser._parse_title(title)
            if make:
                data['make'] = make
            if model:
                data['model'] = model
            if year:
                data['year'] = year
            data['raw_data']['title'] = title
        
        # Извлекаем цену (текущая ставка или оценка)
        price = IAAIParser._extract_price(soup)
        if price:
            data['price'] = price
        
        # Извлекаем пробег
        mileage = IAAIParser._extract_mileage(soup)
        if mileage:
            data['mileage'] = mileage
        
        # Извлекаем цвет
        color = IAAIParser._extract_color(soup)
        if color:
            data['color'] = color
        
        # Извлекаем тип повреждения
        damage_type = IAAIParser._extract_damage(soup)
        if damage_type:
            data['damage_type'] = damage_type
        
        # Извлекаем локацию
        location = IAAIParser._extract_location(soup)
        if location:
            data['location'] = location
        
        # Извлекаем дату окончания аукциона
        auction_end = IAAIParser._extract_auction_end_date(soup)
        if auction_end:
            data['auction_end_date'] = auction_end
        
        # Извлекаем фото
        images = IAAIParser._extract_images(soup)
        if images:
            data['images'] = images
            data['raw_data']['images'] = images
        
        return data
    
    @staticmethod
    def _extract_source_id(url: str) -> str:
        """Извлекает source_id из URL"""
        # Примеры:
        # - /VehicleDetail/44335311~US -> 44335311
        # - https://www.iaai.com/Vehicle/12345678 -> 12345678
        # - /Lot/12345678 -> 12345678
        
        # Сначала пробуем формат /VehicleDetail/ID~COUNTRY (основной формат)
        match = re.search(r'/VehicleDetail/(\d+)', url, re.I)
        if match:
            return match.group(1)
        
        # Пробуем различные паттерны
        patterns = [
            r'/(?:Vehicle|Lot|Detail|vehicles|vehicle|lot|detail|auction|item)/(\d+)',
            r'/(\d+)(?:\?|$)',
            r'[^/]/(\d+)$',
        ]
        
        for pattern in patterns:
            match = re.search(pattern, url, re.I)
            if match:
                return match.group(1)
        
        # Fallback: используем последнюю часть URL (убираем query параметры)
        last_part = url.split('/')[-1].split('?')[0].split('~')[0]  # Убираем ~US и т.д.
        # Если это число, возвращаем его
        if re.match(r'^\d+$', last_part):
            return last_part
        
        return last_part
    
    @staticmethod
    def _extract_stock_number(soup: BeautifulSoup) -> Optional[str]:
        """Извлекает Stock # из HTML"""
        # Ищем по label "Stock #:"
        stock_labels = soup.find_all(string=re.compile(r'Stock\s*#\s*:', re.I))
        for label in stock_labels:
            parent = label.parent
            if parent:
                # Ищем значение в следующем sibling или в том же элементе
                value_elem = parent.find_next_sibling(class_=re.compile(r'value|data-list__value', re.I))
                if not value_elem:
                    value_elem = parent.find('span', class_=re.compile(r'value|data-list__value', re.I))
                if not value_elem:
                    # Пробуем найти следующий элемент с классом text-bold
                    value_elem = parent.find_next('span', class_=re.compile(r'text-bold|bold', re.I))
                
                if value_elem:
                    stock_text = value_elem.get_text(strip=True)
                    # Stock # обычно числовой
                    if stock_text and re.match(r'^\d+$', stock_text):
                        return stock_text
        
        # Альтернативный поиск: ищем в data-list элементах
        data_list_items = soup.find_all('li', class_=re.compile(r'data-list__item', re.I))
        for item in data_list_items:
            label = item.find('span', class_=re.compile(r'data-list__label', re.I))
            if label and re.search(r'Stock\s*#', label.get_text(), re.I):
                value = item.find('span', class_=re.compile(r'data-list__value', re.I))
                if value:
                    stock_text = value.get_text(strip=True)
                    if stock_text and re.match(r'^\d+$', stock_text):
                        return stock_text
        
        return None
    
    @staticmethod
    def _extract_vin(soup: BeautifulSoup) -> Optional[str]:
        """Извлекает VIN номер (полный или partial)"""
        # Ищем VIN в тексте (обычно 17 символов)
        text = soup.get_text()
        vin_pattern = r'\b([A-HJ-NPR-Z0-9]{17})\b'
        match = re.search(vin_pattern, text)
        if match:
            return match.group(1)
        
        # Ищем в специальных полях
        vin_labels = soup.find_all(string=re.compile(r'VIN|Vehicle Identification Number', re.I))
        for label in vin_labels:
            parent = label.parent
            if parent:
                next_sibling = parent.find_next_sibling()
                if next_sibling:
                    vin_text = next_sibling.get_text(strip=True)
                    # Проверяем полный VIN (17 символов)
                    if re.match(r'^[A-HJ-NPR-Z0-9]{17}$', vin_text):
                        return vin_text
                    # Проверяем partial VIN (11-13 символов, может быть с маскировкой)
                    partial_match = re.match(r'^([A-HJ-NPR-Z0-9]{11,13})', vin_text.replace('*', ''))
                    if partial_match:
                        return partial_match.group(1)
        
        # Ищем partial VIN с маскировкой (например: 1FMCU0G76FU******)
        partial_vin_pattern = r'\b([A-HJ-NPR-Z0-9]{11,13})\*+\b'
        match = re.search(partial_vin_pattern, text)
        if match:
            return match.group(1)
        
        return None
    
    @staticmethod
    def _extract_partial_vin(soup: BeautifulSoup) -> Optional[str]:
        """Извлекает partial VIN (первые видимые символы)"""
        # Сначала пробуем извлечь полный VIN
        vin = IAAIParser._extract_vin(soup)
        if vin:
            # Если VIN полный (17 символов), возвращаем первые 13
            if len(vin) >= 17:
                return vin[0:13]
            # Если уже partial (11-13 символов), возвращаем как есть
            if len(vin) >= 11:
                return vin[0:13]
        
        # Ищем partial VIN с маскировкой в HTML
        text = soup.get_text()
        # Паттерн для partial VIN с маскировкой: 1FMCU0G76FU******
        partial_pattern = r'\b([A-HJ-NPR-Z0-9]{11,13})\*+\b'
        match = re.search(partial_pattern, text)
        if match:
            return match.group(1)
        
        # Ищем в полях VIN с маскировкой
        vin_elements = soup.find_all(string=re.compile(r'VIN', re.I))
        for elem in vin_elements:
            parent = elem.parent
            if parent:
                vin_text = parent.get_text()
                # Ищем partial VIN в тексте
                partial_match = re.search(r'([A-HJ-NPR-Z0-9]{11,13})\*+', vin_text)
                if partial_match:
                    return partial_match.group(1)
        
        return None
    
    @staticmethod
    def _extract_title(soup: BeautifulSoup) -> Optional[str]:
        """Извлекает заголовок"""
        # Пробуем разные селекторы
        title = soup.find('h1')
        if not title:
            title = soup.find('title')
        if not title:
            title = soup.find(['h2', 'h3'], class_=re.compile(r'title|heading|vehicle-title', re.I))
        
        return title.get_text(strip=True) if title else None
    
    @staticmethod
    def _parse_title(title: str) -> tuple:
        """Парсит заголовок и извлекает make, model, year"""
        # Пример: "2023 Audi Q5 Premium 45 TFSI"
        parts = title.split()
        
        # Ищем год (4 цифры)
        year = None
        year_index = -1
        for i, part in enumerate(parts):
            if re.match(r'^(19|20)\d{2}$', part):
                year = int(part)
                year_index = i
                break
        
        # Make обычно после года или в начале
        # Model обычно после make
        if year_index >= 0:
            make = parts[year_index + 1] if len(parts) > year_index + 1 else None
            model = parts[year_index + 2] if len(parts) > year_index + 2 else None
            
            # Модель может состоять из нескольких слов
            if year_index + 3 < len(parts):
                model_parts = parts[year_index + 2:year_index + 4]
                model = ' '.join(model_parts)
        else:
            # Если год не найден, пробуем первые слова
            make = parts[0] if len(parts) > 0 else None
            model = parts[1] if len(parts) > 1 else None
        
        return (make, model, year)
    
    @staticmethod
    def _extract_price(soup: BeautifulSoup) -> Optional[float]:
        """Извлекает цену (текущая ставка или оценка)"""
        text = soup.get_text()
        price_patterns = [
            r'Current Bid:[\s]*\$?([\d,]+)',
            r'Bid:[\s]*\$?([\d,]+)',
            r'Estimate:[\s]*\$?([\d,]+)',
            r'\$[\s]*([\d,]+)',
            r'([\d,]+)[\s]*USD'
        ]
        
        for pattern in price_patterns:
            match = re.search(pattern, text, re.I)
            if match:
                price_str = match.group(1).replace(',', '')
                try:
                    return float(price_str)
                except:
                    continue
        
        return None
    
    @staticmethod
    def _extract_mileage(soup: BeautifulSoup) -> Optional[int]:
        """Извлекает пробег"""
        text = soup.get_text()
        mileage_patterns = [
            r'Mileage:[\s]*([\d,]+)',
            r'Odometer:[\s]*([\d,]+)',
            r'([\d,]+)[\s]*mi',
            r'([\d,]+)[\s]*miles'
        ]
        
        for pattern in mileage_patterns:
            match = re.search(pattern, text, re.I)
            if match:
                mileage_str = match.group(1).replace(',', '')
                try:
                    return int(mileage_str)
                except:
                    continue
        
        return None
    
    @staticmethod
    def _extract_color(soup: BeautifulSoup) -> Optional[str]:
        """Извлекает цвет"""
        text = soup.get_text()
        color_pattern = r'Color:[\s]*([A-Za-z\s]+)'
        match = re.search(color_pattern, text, re.I)
        if match:
            return match.group(1).strip()
        
        # Ищем в заголовке
        title = IAAIParser._extract_title(soup)
        if title:
            colors = ['black', 'white', 'red', 'blue', 'green', 'gray', 'grey', 'silver', 'brown', 'beige']
            title_lower = title.lower()
            for color in colors:
                if color in title_lower:
                    return color.capitalize()
        
        return None
    
    @staticmethod
    def _extract_damage(soup: BeautifulSoup) -> Optional[str]:
        """Извлекает тип повреждения"""
        text = soup.get_text()
        damage_patterns = [
            r'Damage:[\s]*([A-Za-z\s]+)',
            r'Damage Type:[\s]*([A-Za-z\s]+)',
            r'Condition:[\s]*([A-Za-z\s]+)',
            r'Primary Damage:[\s]*([A-Za-z\s]+)',
            r'Secondary Damage:[\s]*([A-Za-z\s]+)'
        ]
        
        for pattern in damage_patterns:
            match = re.search(pattern, text, re.I)
            if match:
                damage = match.group(1).strip()
                # Нормализуем
                damage_lower = damage.lower()
                if 'none' in damage_lower or 'no damage' in damage_lower:
                    return 'None'
                elif 'minor' in damage_lower:
                    return 'Minor'
                elif 'moderate' in damage_lower:
                    return 'Moderate'
                elif 'severe' in damage_lower or 'major' in damage_lower:
                    return 'Severe'
                elif 'total' in damage_lower or 'salvage' in damage_lower:
                    return 'Total Loss'
                return damage
        
        return None
    
    @staticmethod
    def _extract_location(soup: BeautifulSoup) -> Optional[str]:
        """Извлекает локацию"""
        text = soup.get_text()
        location_patterns = [
            r'Location:[\s]*([A-Za-z\s,]+)',
            r'Sale Location:[\s]*([A-Za-z\s,]+)',
            r'Auction Location:[\s]*([A-Za-z\s,]+)',
            r'Branch:[\s]*([A-Za-z\s,]+)'
        ]
        
        for pattern in location_patterns:
            match = re.search(pattern, text, re.I)
            if match:
                return match.group(1).strip()
        
        return None
    
    @staticmethod
    def _extract_auction_end_date(soup: BeautifulSoup) -> Optional[float]:
        """Извлекает дату окончания аукциона (timestamp)"""
        text = soup.get_text()
        date_patterns = [
            r'Auction Date:[\s]*([A-Za-z0-9\s,:-]+)',
            r'Sale Date:[\s]*([A-Za-z0-9\s,:-]+)',
            r'Ends:[\s]*([A-Za-z0-9\s,:-]+)',
            r'End Date:[\s]*([A-Za-z0-9\s,:-]+)'
        ]
        
        # Парсим дату и конвертируем в timestamp
        # Это упрощенная версия, может потребоваться более сложный парсинг
        import datetime
        for pattern in date_patterns:
            match = re.search(pattern, text, re.I)
            if match:
                date_str = match.group(1).strip()
                # Попытка парсинга (упрощенная)
                try:
                    # Здесь можно добавить более сложный парсинг дат
                    # Пока возвращаем None, так как формат даты может быть разным
                    pass
                except:
                    pass
        
        return None
    
    @staticmethod
    def _extract_images(soup: BeautifulSoup) -> List[str]:
        """Извлекает ссылки на фото"""
        images = []
        
        # Ищем все img теги
        img_tags = soup.find_all('img')
        for img in img_tags:
            src = img.get('src') or img.get('data-src') or img.get('data-lazy-src') or img.get('data-original')
            if src and ('vehicle' in src.lower() or 'image' in src.lower() or 'photo' in src.lower()):
                if not src.startswith('http'):
                    src = IAAIParser.BASE_URL + src
                images.append(src)
        
        # Убираем дубликаты
        return list(set(images))
    
    @staticmethod
    def find_pagination(soup: BeautifulSoup) -> Dict[str, any]:
        """
        Находит информацию о пагинации
        
        Returns:
            Dict с ключами:
            - next_page: URL следующей страницы или None
            - current_page: номер текущей страницы
            - total_pages: общее количество страниц или None
            - has_next: есть ли следующая страница
        """
        result = {
            'next_page': None,
            'current_page': 1,
            'total_pages': None,
            'has_next': False
        }
        
        # Ищем ссылку на следующую страницу
        next_link = soup.find('a', string=re.compile(r'next|следующ', re.I))
        if not next_link:
            next_link = soup.find('a', class_=re.compile(r'next', re.I))
        if not next_link:
            # Пробуем найти по href
            next_link = soup.find('a', href=re.compile(r'page=\d+', re.I))
        
        if next_link and next_link.get('href'):
            href = next_link.get('href')
            if not href.startswith('http'):
                href = IAAIParser.BASE_URL + href
            result['next_page'] = href
            result['has_next'] = True
        
        # Ищем текущую страницу
        current_page_elem = soup.find(['span', 'a'], class_=re.compile(r'current|active|page.*current', re.I))
        if current_page_elem:
            page_text = current_page_elem.get_text(strip=True)
            page_match = re.search(r'(\d+)', page_text)
            if page_match:
                result['current_page'] = int(page_match.group(1))
        
        # Ищем общее количество страниц
        page_info = soup.find(string=re.compile(r'page.*of|of.*page|total.*page', re.I))
        if page_info:
            total_match = re.search(r'of\s+(\d+)|total.*?(\d+)', page_info, re.I)
            if total_match:
                result['total_pages'] = int(total_match.group(1) or total_match.group(2))
        
        return result


